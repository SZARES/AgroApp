import 'dart:async';

import '../../domain/models/outbox_record.dart';
import '../../domain/models/sync_op.dart';
import '../../domain/models/sync_summary.dart';
import '../../utils/result.dart';
import '../repositories/local_store.dart';
import '../repositories/outbox_repository.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import 'sync_tables.dart';

class SyncReport {
  const SyncReport({this.synced = 0, this.failed = 0});

  final int synced;
  final int failed;
}

/// The only component that talks to the backend: pushes the outbox, then
/// pulls every replicated table into the local database.
class SyncEngine {
  SyncEngine({
    required OutboxRepository repository,
    required LocalStore localStore,
    required SyncService syncService,
    required ConnectivityService connectivity,
    this.batchSize = 50,
    this.maxAttempts = 5,
    this.pullPageSize = 1000,
    this.tickInterval = const Duration(seconds: 5),
    this.pullInterval = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _repository = repository,
       _localStore = localStore,
       _syncService = syncService,
       _connectivity = connectivity,
       _clock = clock ?? DateTime.now;

  final OutboxRepository _repository;
  final LocalStore _localStore;
  final SyncService _syncService;
  final ConnectivityService _connectivity;
  final DateTime Function() _clock;
  final int batchSize;
  final int maxAttempts;
  final int pullPageSize;
  final Duration tickInterval;
  final Duration pullInterval;

  StreamSubscription<bool>? _subscription;
  Timer? _timer;
  bool _isRunning = false;
  DateTime? _lastPullAt;
  int _generation = 0;

  final _snapshots = StreamController<SyncSnapshot>.broadcast();
  SyncSnapshot _snapshot = const SyncSnapshot();

  /// Latest engine state; [snapshots] emits on every change.
  SyncSnapshot get snapshot => _snapshot;
  Stream<SyncSnapshot> get snapshots => _snapshots.stream;

  /// Recovers interrupted records, syncs once, then syncs every few seconds
  /// and again whenever the device comes back online.
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _connectivity.onStatusChange.listen((online) {
      _emit(_snapshot.copyWith(isOnline: online));
      if (online) unawaited(syncNow(retryFailed: true, forcePull: true));
    });
    await _repository.requeueInterrupted();
    _timer = Timer.periodic(tickInterval, (_) => unawaited(syncNow()));
    unawaited(syncNow(forcePull: true));
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _snapshots.close();
  }

  /// Wipes all local data when a different user signs in.
  Future<void> resetForNewUser() async {
    _generation++;
    _lastPullAt = null;
    await _localStore.clearAll();
    await _refreshCounts();
  }

  /// Pushes pending changes, then pulls when due (every [pullInterval], after
  /// a push that delivered something, or when [forcePull] is set).
  ///
  /// With [retryFailed], records that exhausted their attempts get a fresh
  /// set first. Returns an empty report when offline or already running.
  Future<Result<SyncReport>> syncNow({
    bool retryFailed = false,
    bool forcePull = false,
  }) async {
    if (_isRunning) return const Result.ok(SyncReport());
    _isRunning = true;
    _emit(_snapshot.copyWith(isSyncing: true));
    try {
      final online = await _connectivity.isOnline();
      _emit(_snapshot.copyWith(isOnline: online));
      if (!online) return const Result.ok(SyncReport());

      if (retryFailed) await _repository.resetAttempts();
      final pushed = await _push();
      final report = pushed is Ok<SyncReport>
          ? pushed.value
          : const SyncReport();

      final due =
          _lastPullAt == null ||
          _clock().difference(_lastPullAt!) >= pullInterval;
      if (forcePull || report.synced > 0 || due) {
        await _pull();
      }
      return pushed;
    } catch (error) {
      return Result.error(_asException(error));
    } finally {
      _isRunning = false;
      await _refreshCounts(isSyncing: false);
    }
  }

  /// Uploads one batch of pending records (no pull).
  ///
  /// Returns an empty report when offline, when nothing is pending, or when
  /// another run is already in flight.
  Future<Result<SyncReport>> syncPending() async {
    if (_isRunning) return const Result.ok(SyncReport());
    _isRunning = true;
    try {
      if (!await _connectivity.isOnline()) return const Result.ok(SyncReport());
      return await _push();
    } catch (error) {
      return Result.error(_asException(error));
    } finally {
      _isRunning = false;
      await _refreshCounts(isSyncing: false);
    }
  }

  // --- push ---------------------------------------------------------------

  Future<Result<SyncReport>> _push() async {
    final records = await _repository.pendingBatch(
      limit: batchSize,
      maxAttempts: maxAttempts,
    );
    if (records.isEmpty) return const Result.ok(SyncReport());

    await _repository.markSyncing(records.map((record) => record.id));

    final batch = records.where((record) => record.op == SyncOp.batch).toList()
      ..sort((a, b) => a.clientCreatedAt.compareTo(b.clientCreatedAt));
    final singles =
        records.where((record) => record.op != SyncOp.batch).toList()
          ..sort((a, b) => a.clientCreatedAt.compareTo(b.clientCreatedAt));

    var synced = 0;
    var failed = 0;
    Object? transportError;

    if (batch.isNotEmpty) {
      try {
        final result = await _pushBatch(batch);
        synced += result.synced;
        failed += result.failed;
      } catch (error) {
        transportError = error;
        failed += batch.length;
        await _markFailed(batch.map((record) => record.id), error.toString());
      }
    }

    for (final record in singles) {
      try {
        await _pushSingle(record);
        await _repository.markSynced([record.id]);
        await _localStore.settle([record]);
        synced++;
      } catch (error) {
        failed++;
        await _repository.markFailed(record.id, error.toString());
      }
    }

    if (transportError != null) {
      return Result.error(_asException(transportError));
    }
    return Result.ok(SyncReport(synced: synced, failed: failed));
  }

  Future<SyncReport> _pushBatch(List<OutboxRecord> batch) async {
    final result = await _syncService.syncBatch(
      deviceId: await _repository.deviceId(),
      records: batch,
    );
    final byId = {for (final record in batch) record.id: record};
    final unresolved = byId.keys.toSet();

    final synced = result.syncedIds.where(unresolved.remove).toList();
    await _repository.markSynced(synced);
    await _localStore.settle([for (final id in synced) byId[id]!]);

    var failed = 0;
    for (final failure in result.failures) {
      if (!unresolved.remove(failure.id)) continue;
      await _repository.markFailed(failure.id, failure.error);
      failed++;
    }

    failed += unresolved.length;
    await _markFailed(unresolved, 'Record missing from the sync response');

    return SyncReport(synced: synced.length, failed: failed);
  }

  Future<void> _pushSingle(OutboxRecord record) {
    final id = _localStore.rowIdOf(record);
    return switch (record.op) {
      SyncOp.update => _syncService.updateRow(
        record.tableName,
        id,
        {...record.payload}..remove('id'),
      ),
      _ => _syncService.upsertRow(record.tableName, record.payload),
    };
  }

  Future<void> _markFailed(Iterable<String> ids, String error) async {
    for (final id in ids) {
      await _repository.markFailed(id, error);
    }
  }

  // --- pull ---------------------------------------------------------------

  Future<void> _pull() async {
    final generation = _generation;
    var allOk = true;
    for (final table in SyncTables.pullTables) {
      if (generation != _generation) return;
      try {
        await _pullTable(table, generation);
      } catch (_) {
        // One table failing (e.g. no access for this role) must not block the
        // rest; it is retried on the next pull.
        allOk = false;
      }
    }
    if (generation != _generation) return;
    _lastPullAt = _clock();
    if (allOk) {
      _emit(_snapshot.copyWith(lastSyncedAt: _lastPullAt));
    }
  }

  Future<void> _pullTable(SyncTable table, int generation) async {
    if (table.fullRefresh) {
      final rows = await _syncService.pullAll(table.name);
      if (generation != _generation) return;
      await _localStore.replaceTable(table.name, rows, idOf: table.rowId);
      return;
    }

    var cursor = await _localStore.readCursor(table.name);
    while (true) {
      final rows = await _syncService.pullTable(
        table.name,
        since: cursor,
        cursorColumn: table.cursorColumn,
        limit: pullPageSize,
      );
      if (generation != _generation) return;
      if (rows.isEmpty) return;

      await _localStore.applyServerRows(table.name, rows, idOf: table.rowId);

      final next = _maxCursor(rows, table.cursorColumn);
      if (next != null && (cursor == null || next.isAfter(cursor))) {
        await _localStore.writeCursor(table.name, next);
        cursor = next;
      } else {
        return; // The cursor did not advance; avoid looping forever.
      }
      if (rows.length < pullPageSize) return;
    }
  }

  DateTime? _maxCursor(List<Map<String, dynamic>> rows, String column) {
    DateTime? max;
    for (final row in rows) {
      final value = row[column];
      final parsed = value is String ? DateTime.tryParse(value) : null;
      if (parsed != null && (max == null || parsed.isAfter(max))) max = parsed;
    }
    return max;
  }

  // --- state --------------------------------------------------------------

  Future<void> _refreshCounts({bool? isSyncing}) async {
    if (_snapshots.isClosed) return;
    try {
      final summary = await _repository.summary();
      _emit(
        _snapshot.copyWith(
          isSyncing: isSyncing,
          pendingCount: summary.pending,
          failedCount: summary.error,
        ),
      );
    } catch (_) {
      // The database may already be closed during shutdown.
      _emit(_snapshot.copyWith(isSyncing: isSyncing));
    }
  }

  void _emit(SyncSnapshot next) {
    if (next == _snapshot || _snapshots.isClosed) return;
    _snapshot = next;
    _snapshots.add(next);
  }

  Exception _asException(Object error) =>
      error is Exception ? error : Exception(error.toString());
}
