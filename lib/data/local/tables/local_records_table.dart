import 'package:drift/drift.dart';

/// Offline replica of the Supabase rows the signed-in user can see.
///
/// Every backend table shares this one generic table; [data] holds the full
/// server row as JSON.
@DataClassName('LocalRecordRow')
class LocalRecords extends Table {
  /// Backend table the row belongs to (named to avoid clashing with
  /// `Table.tableName`).
  TextColumn get sourceTable => text().named('table_name')();

  /// Row id; composite keys are joined with `|`.
  TextColumn get id => text()();

  /// JSON-encoded server row.
  TextColumn get data => text()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// True while a local change has not reached the server yet.
  BoolColumn get pending => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {sourceTable, id};
}
