import 'package:drift/drift.dart';

import '../../../domain/models/sync_status.dart';

@DataClassName('OutboxRow')
class Outbox extends Table {
  /// Client-generated UUID, reused as the server row id for idempotency.
  TextColumn get id => text()();

  TextColumn get targetTable => text().named('table_name')();

  /// JSON-encoded object sent as the record payload.
  TextColumn get payload => text()();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get clientCreatedAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
