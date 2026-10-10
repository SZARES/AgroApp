import 'dart:async';

import '../../utils/result.dart';
import '../repositories/outbox_repository.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

class SyncReport {
  const SyncReport({this.synced = 0, this.failed = 0});

  final int synced;
  final int failed;
}

/// The only component that uploads outbox records to the backend.
class SyncEngine {
  SyncEngine({
    required OutboxRepository repository,
    required SyncService syncService,
    required ConnectivityService connectivity,
    this.batchSize = 50,
  }) : _repository = repository,
       _syncService = syncService,
       _connectivity = connectivity;

  final OutboxRepository _repository;
  final SyncService _syncService;
  final ConnectivityService _connectivity;
  final int batchSize;

  StreamSubscription<bool>? _subscription;
  bool _isRunning = false;

  /// Recovers interrupted records, syncs once, then syncs again every time
  /// the device comes back online.
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _connectivity.onStatusChange.listen((online) {
      if (online) unawaited(syncPending());
    });
    await _repository.requeueInterrupted();
    unawaited(syncPending());
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Uploads one batch of pending records.
  ///
  /// Returns an empty report when offline, when nothing is pending, or when
  /// another run is already in flight.
  Future<Result<SyncReport>> syncPending() async {
    if (_isRunning) return const Result.ok(SyncReport());
    _isRunning = true;
    try {
      return await _syncBatch();
    } catch (error) {
      return Result.error(_asException(error));
    } finally {
      _isRunning = false;
    }
  }

  Future<Result<SyncReport>> _syncBatch() async {
    if (!await _connectivity.isOnline()) return const Result.ok(SyncReport());

    final batch = await _repository.pendingBatch(limit: batchSize);
    if (batch.isEmpty) return const Result.ok(SyncReport());

    final unresolved = {for (final record in batch) record.id};
    await _repository.markSyncing(unresolved);

    final SyncBatchResult result;
    try {
      result = await _syncService.syncBatch(
        deviceId: await _repository.deviceId(),
        records: batch,
      );
    } catch (error) {
      await _markFailed(unresolved, error.toString());
      return Result.error(_asException(error));
    }

    final synced = result.syncedIds.where(unresolved.remove).toList();
    await _repository.markSynced(synced);

    var failed = 0;
    for (final failure in result.failures) {
      if (!unresolved.remove(failure.id)) continue;
      await _repository.markFailed(failure.id, failure.error);
      failed++;
    }

    failed += unresolved.length;
    await _markFailed(unresolved, 'Record missing from the sync response');

    return Result.ok(SyncReport(synced: synced.length, failed: failed));
  }

  Future<void> _markFailed(Iterable<String> ids, String error) async {
    for (final id in ids) {
      await _repository.markFailed(id, error);
    }
  }

  Exception _asException(Object error) =>
      error is Exception ? error : Exception(error.toString());
}
