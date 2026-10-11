import 'dart:async';

import 'package:hackathon/data/services/connectivity_service.dart';
import 'package:hackathon/data/services/sync_service.dart';
import 'package:hackathon/domain/models/outbox_record.dart';

typedef SyncHandler =
    FutureOr<SyncBatchResult> Function(List<OutboxRecord> records);

class FakeSyncService implements SyncService {
  FakeSyncService([this.handler]);

  /// Defaults to accepting every record.
  SyncHandler? handler;

  final List<List<OutboxRecord>> batches = [];
  final List<String> deviceIds = [];

  /// Rows returned by [pullTable]/[pullAll], per table. Pages are served by
  /// filtering on the cursor column like the real backend does.
  final Map<String, List<Map<String, dynamic>>> serverRows = {};
  final List<({String table, DateTime? since, int limit})> pulls = [];
  final List<String> pullAlls = [];
  final List<({String table, Map<String, dynamic> row})> upserts = [];
  final List<({String table, String id, Map<String, dynamic> changes})>
  updates = [];

  /// Tables whose pull throws.
  final Set<String> failingPulls = {};

  /// Row ids whose upsert/update throws.
  final Set<String> failingRows = {};

  @override
  Future<SyncBatchResult> syncBatch({
    required String deviceId,
    required List<OutboxRecord> records,
  }) async {
    deviceIds.add(deviceId);
    batches.add(records);
    final handler = this.handler;
    if (handler != null) return handler(records);
    return SyncBatchResult(
      syncedIds: [for (final record in records) record.id],
      failures: const [],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> pullTable(
    String table, {
    DateTime? since,
    String cursorColumn = 'updated_at',
    int limit = 1000,
  }) async {
    pulls.add((table: table, since: since, limit: limit));
    if (failingPulls.contains(table)) throw Exception('pull failed: $table');
    final rows = [...?serverRows[table]]
      ..sort(
        (a, b) => DateTime.parse(
          a[cursorColumn] as String,
        ).compareTo(DateTime.parse(b[cursorColumn] as String)),
      );
    return rows
        .where(
          (row) =>
              since == null ||
              DateTime.parse(row[cursorColumn] as String).isAfter(since),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> pullAll(String table) async {
    pullAlls.add(table);
    if (failingPulls.contains(table)) throw Exception('pull failed: $table');
    return [...?serverRows[table]];
  }

  @override
  Future<void> upsertRow(String table, Map<String, dynamic> row) async {
    if (failingRows.contains(row['id'])) {
      throw Exception('rejected ${row['id']}');
    }
    upserts.add((table: table, row: row));
  }

  @override
  Future<void> updateRow(
    String table,
    String id,
    Map<String, dynamic> changes,
  ) async {
    if (failingRows.contains(id)) throw Exception('rejected $id');
    updates.add((table: table, id: id, changes: changes));
  }
}

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  bool online;

  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  void setOnline(bool value) {
    online = value;
    _controller.add(value);
  }

  Future<void> close() => _controller.close();
}
