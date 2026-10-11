import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/outbox_record.dart';
import '../../domain/models/sync_op.dart';
import '../../domain/models/sync_status.dart';
import '../../domain/models/sync_summary.dart';
import '../local/app_database.dart';

/// Single source of truth for records waiting to be uploaded.
///
/// Reads and writes the local database only; uploading is the sync engine's
/// job.
class OutboxRepository {
  OutboxRepository(this._database, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  static const _deviceIdKey = 'device_id';

  final AppDatabase _database;
  final Uuid _uuid;

  Future<OutboxRecord> enqueue({
    required String tableName,
    required Map<String, dynamic> payload,
    String? id,
    SyncOp op = SyncOp.batch,
  }) async {
    final now = DateTime.now();
    final row = await _database
        .into(_database.outbox)
        .insertReturning(
          OutboxCompanion.insert(
            id: id ?? _uuid.v4(),
            targetTable: tableName,
            payload: jsonEncode(payload),
            syncStatus: SyncStatus.pending,
            op: Value(op.name),
            clientCreatedAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
    return _toRecord(row);
  }

  /// Records eligible for upload: never sent, or failed on an earlier attempt.
  ///
  /// Records with fewer attempts come first so one that keeps failing cannot
  /// hold back newer ones.
  ///
  /// Records that already failed [maxAttempts] times are skipped until
  /// [resetAttempts] is called.
  Future<List<OutboxRecord>> pendingBatch({
    int limit = 50,
    int? maxAttempts,
  }) async {
    final query = _database.select(_database.outbox)
      ..where(
        (row) =>
            row.syncStatus.isInValues([SyncStatus.pending, SyncStatus.error]) &
            (maxAttempts == null
                ? const Constant(true)
                : row.attempts.isSmallerThanValue(maxAttempts)),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.attempts),
        (row) => OrderingTerm.asc(row.clientCreatedAt),
      ])
      ..limit(limit);
    final rows = await query.get();
    return rows.map(_toRecord).toList();
  }

  Future<void> markSyncing(Iterable<String> ids) =>
      _setStatus(ids, SyncStatus.syncing);

  Future<void> markSynced(Iterable<String> ids) => _setStatus(
    ids,
    SyncStatus.synced,
    extra: const OutboxCompanion(lastError: Value(null)),
  );

  Future<void> markFailed(String id, String error) {
    final outbox = _database.outbox;
    return (_database.update(outbox)..where((row) => row.id.equals(id))).write(
      OutboxCompanion.custom(
        syncStatus: Variable(SyncStatus.error.name),
        attempts: outbox.attempts + const Constant(1),
        lastError: Variable(error),
        updatedAt: Variable(DateTime.now()),
      ),
    );
  }

  /// Gives failed records a fresh set of attempts (e.g. after reconnecting).
  Future<void> resetAttempts() {
    final update = _database.update(_database.outbox)
      ..where((row) => row.syncStatus.equalsValue(SyncStatus.error));
    return update.write(const OutboxCompanion(attempts: Value(0)));
  }

  /// Current counts of unsent records.
  Future<SyncSummary> summary() => watchSummary().first;

  /// Returns records left in `syncing` by an interrupted run to `pending`.
  Future<void> requeueInterrupted() {
    final update = _database.update(_database.outbox)
      ..where((row) => row.syncStatus.equalsValue(SyncStatus.syncing));
    return update.write(
      OutboxCompanion(
        syncStatus: const Value(SyncStatus.pending),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Stream<SyncSummary> watchSummary() {
    final outbox = _database.outbox;
    final count = outbox.id.count();
    final query = _database.selectOnly(outbox)
      ..addColumns([outbox.syncStatus, count])
      ..groupBy([outbox.syncStatus]);
    return query.watch().map((rows) {
      final counts = {
        for (final row in rows) row.read(outbox.syncStatus): row.read(count),
      };
      int of(SyncStatus status) => counts[status.name] ?? 0;
      return SyncSummary(
        pending: of(SyncStatus.pending) + of(SyncStatus.syncing),
        error: of(SyncStatus.error),
      );
    }).distinct();
  }

  /// Identifier of this installation, generated on first use.
  Future<String> deviceId() {
    final settings = _database.appSettings;
    return _database.transaction(() async {
      final existing = await (_database.select(
        settings,
      )..where((row) => row.key.equals(_deviceIdKey))).getSingleOrNull();
      if (existing != null) return existing.value;

      final generated = _uuid.v4();
      await _database
          .into(settings)
          .insert(
            AppSettingsCompanion.insert(key: _deviceIdKey, value: generated),
          );
      return generated;
    });
  }

  Future<void> _setStatus(
    Iterable<String> ids,
    SyncStatus status, {
    OutboxCompanion extra = const OutboxCompanion(),
  }) {
    final update = _database.update(_database.outbox)
      ..where((row) => row.id.isIn(ids));
    return update.write(
      extra.copyWith(
        syncStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  OutboxRecord _toRecord(OutboxRow row) {
    return OutboxRecord(
      id: row.id,
      tableName: row.targetTable,
      payload: jsonDecode(row.payload) as Map<String, dynamic>,
      status: row.syncStatus,
      attempts: row.attempts,
      lastError: row.lastError,
      op: SyncOp.parse(row.op),
      clientCreatedAt: row.clientCreatedAt,
      updatedAt: row.updatedAt,
    );
  }
}
