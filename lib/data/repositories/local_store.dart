import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/outbox_record.dart';
import '../../domain/models/sync_op.dart';
import '../../domain/models/sync_status.dart';
import '../local/app_database.dart';
import 'outbox_repository.dart';

typedef JsonMap = Map<String, dynamic>;

/// The single API features use to read and write domain data.
///
/// Reads come from the local replica; writes update the replica and queue the
/// change in the outbox atomically. Only the sync engine talks to Supabase.
class LocalStore {
  LocalStore(
    this._database,
    this._outbox, {
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
  }) : _uuid = uuid,
       _clock = clock ?? DateTime.now;

  static const cursorKeyPrefix = 'pull_cursor:';

  final AppDatabase _database;
  final OutboxRepository _outbox;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// New client-generated row id (UUID v4).
  String newId() => _uuid.v4();

  $LocalRecordsTable get _records => _database.localRecords;

  /// Live rows of [table] (soft-deleted ones excluded), optionally filtered.
  Stream<List<JsonMap>> watchTable(
    String table, {
    bool Function(JsonMap)? where,
  }) {
    final query = _database.select(_records)
      ..where((r) => r.sourceTable.equals(table) & r.deletedAt.isNull());
    return query.watch().map((rows) => _decode(rows, where));
  }

  Future<JsonMap?> get(String table, String id) async {
    final row =
        await (_database.select(_records)
              ..where((r) => r.sourceTable.equals(table) & r.id.equals(id)))
            .getSingleOrNull();
    return row == null ? null : _toRow(row);
  }

  Future<List<JsonMap>> list(
    String table, {
    bool Function(JsonMap)? where,
  }) async {
    final query = _database.select(_records)
      ..where((r) => r.sourceTable.equals(table) & r.deletedAt.isNull());
    return _decode(await query.get(), where);
  }

  Future<bool> isPending(String table, String id) async {
    final row =
        await (_database.select(_records)
              ..where((r) => r.sourceTable.equals(table) & r.id.equals(id)))
            .getSingleOrNull();
    return row?.pending ?? false;
  }

  /// Writes [row] to the replica (merged into any existing row, marked
  /// pending) and queues it for upload, in one transaction.
  ///
  /// For [SyncOp.update] the outbox payload carries only [row]'s fields; for
  /// the other ops it carries the merged row, so an upsert is self-contained.
  Future<void> save({
    required String table,
    required String id,
    required JsonMap row,
    required SyncOp op,
  }) {
    return _database.transaction(() async {
      final existing = await get(table, id);
      final merged = <String, dynamic>{...?existing, ...row, 'id': id};
      final now = _clock();
      await _upsertRow(
        table: table,
        id: id,
        data: merged,
        updatedAt: now,
        pending: true,
      );
      await _outbox.enqueue(
        tableName: table,
        payload: op == SyncOp.update ? {...row, 'id': id} : merged,
        // Batch inserts reuse the row id so the server stays idempotent.
        id: op == SyncOp.batch ? id : null,
        op: op,
      );
    });
  }

  /// Marks the row deleted locally and queues the change (update by default).
  Future<void> softDelete({
    required String table,
    required String id,
    SyncOp op = SyncOp.update,
  }) {
    return save(
      table: table,
      id: id,
      row: {'deleted_at': _clock().toUtc().toIso8601String()},
      op: op,
    );
  }

  /// Applies rows pulled from the server, except those with local changes
  /// still waiting to be pushed (local wins until pushed).
  Future<void> applyServerRows(
    String table,
    Iterable<JsonMap> rows, {
    String Function(JsonMap)? idOf,
  }) {
    return _database.transaction(() async {
      final pendingIds = await _pendingIds(table);
      final companions = <LocalRecordsCompanion>[];
      for (final row in rows) {
        final id = idOf != null ? idOf(row) : '${row['id']}';
        if (pendingIds.contains(id)) continue;
        companions.add(_companion(table, id, row, _serverTime(row), false));
      }
      await _database.batch(
        (batch) => batch.insertAllOnConflictUpdate(_records, companions),
      );
    });
  }

  /// Replaces every non-pending row of [table] with [rows] (full refresh for
  /// tables that have no cursor column).
  Future<void> replaceTable(
    String table,
    Iterable<JsonMap> rows, {
    required String Function(JsonMap) idOf,
  }) {
    return _database.transaction(() async {
      await (_database.delete(_records)..where(
            (r) => r.sourceTable.equals(table) & r.pending.equals(false),
          ))
          .go();
      await applyServerRows(table, rows, idOf: idOf);
    });
  }

  /// Clears the pending flag of rows whose outbox records were delivered,
  /// unless a newer change for the same row is still waiting.
  Future<void> settle(Iterable<OutboxRecord> delivered) {
    return _database.transaction(() async {
      final unsent =
          await (_database.select(_database.outbox)..where(
                (o) => o.syncStatus.isInValues([
                  SyncStatus.pending,
                  SyncStatus.syncing,
                  SyncStatus.error,
                ]),
              ))
              .get();
      final stillWaiting = {
        for (final o in unsent)
          _key(o.targetTable, _rowIdOf(o.id, o.op, o.payload)),
      };
      for (final record in delivered) {
        final id = rowIdOf(record);
        if (stillWaiting.contains(_key(record.tableName, id))) continue;
        await (_database.update(_records)..where(
              (r) => r.sourceTable.equals(record.tableName) & r.id.equals(id),
            ))
            .write(const LocalRecordsCompanion(pending: Value(false)));
      }
    });
  }

  /// Id of the replica row an outbox record targets.
  String rowIdOf(OutboxRecord record) =>
      _rowIdOf(record.id, record.op.name, jsonEncode(record.payload));

  Future<DateTime?> readCursor(String table) async {
    final setting = await (_database.select(
      _database.appSettings,
    )..where((s) => s.key.equals('$cursorKeyPrefix$table'))).getSingleOrNull();
    return setting == null ? null : DateTime.tryParse(setting.value);
  }

  Future<void> writeCursor(String table, DateTime cursor) {
    return _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: '$cursorKeyPrefix$table',
            value: cursor.toUtc().toIso8601String(),
          ),
        );
  }

  /// Wipes the replica, the outbox and the pull cursors (keeps the device id).
  /// Call when a different user signs in so nothing leaks between accounts.
  Future<void> clearAll() {
    return _database.transaction(() async {
      await _database.delete(_records).go();
      await _database.delete(_database.outbox).go();
      await (_database.delete(
        _database.appSettings,
      )..where((s) => s.key.like('$cursorKeyPrefix%'))).go();
    });
  }

  Future<Set<String>> _pendingIds(String table) async {
    final rows =
        await (_database.select(_records)..where(
              (r) => r.sourceTable.equals(table) & r.pending.equals(true),
            ))
            .get();
    return {for (final row in rows) row.id};
  }

  Future<void> _upsertRow({
    required String table,
    required String id,
    required JsonMap data,
    required DateTime updatedAt,
    required bool pending,
  }) {
    return _database
        .into(_records)
        .insertOnConflictUpdate(
          _companion(table, id, data, updatedAt, pending),
        );
  }

  LocalRecordsCompanion _companion(
    String table,
    String id,
    JsonMap data,
    DateTime updatedAt,
    bool pending,
  ) {
    return LocalRecordsCompanion.insert(
      sourceTable: table,
      id: id,
      data: jsonEncode(data),
      updatedAt: updatedAt,
      deletedAt: Value(_parse(data['deleted_at'])),
      pending: Value(pending),
    );
  }

  DateTime _serverTime(JsonMap row) =>
      _parse(row['updated_at']) ??
      _parse(row['created_at']) ??
      _parse(row['changed_at']) ??
      _clock();

  DateTime? _parse(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  String _key(String table, String id) => '$table|$id';

  String _rowIdOf(String outboxId, String op, String payload) {
    if (op == SyncOp.batch.name) return outboxId;
    final decoded = jsonDecode(payload);
    return decoded is Map ? '${decoded['id']}' : outboxId;
  }

  List<JsonMap> _decode(
    List<LocalRecordRow> rows,
    bool Function(JsonMap)? where,
  ) {
    final decoded = rows.map(_toRow);
    return (where == null ? decoded : decoded.where(where)).toList();
  }

  JsonMap _toRow(LocalRecordRow row) =>
      Map<String, dynamic>.from(jsonDecode(row.data) as Map);
}
