import '../../domain/models/outbox_record.dart';

class SyncFailure {
  const SyncFailure({required this.id, required this.error});

  final String id;
  final String error;
}

class SyncBatchResult {
  const SyncBatchResult({required this.syncedIds, required this.failures});

  final List<String> syncedIds;
  final List<SyncFailure> failures;
}

abstract interface class SyncService {
  /// Uploads [records] in one request. A rejected record is reported in
  /// [SyncBatchResult.failures]; only transport-level problems throw.
  Future<SyncBatchResult> syncBatch({
    required String deviceId,
    required List<OutboxRecord> records,
  });

  /// Rows of [table] whose [cursorColumn] is greater than [since], oldest
  /// first, soft-deleted rows included. RLS decides what the user sees.
  Future<List<Map<String, dynamic>>> pullTable(
    String table, {
    DateTime? since,
    String cursorColumn = 'updated_at',
    int limit = 1000,
  });

  /// Every visible row of [table], for tables without a cursor column.
  Future<List<Map<String, dynamic>>> pullAll(String table);

  /// PostgREST upsert keyed on the primary key.
  Future<void> upsertRow(String table, Map<String, dynamic> row);

  /// PostgREST update of one row; throws when no row was changed.
  Future<void> updateRow(String table, String id, Map<String, dynamic> changes);
}
