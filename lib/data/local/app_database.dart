import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/models/sync_status.dart';
import 'tables/app_settings_table.dart';
import 'tables/outbox_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Outbox, AppSettings])
class AppDatabase extends _$AppDatabase {
  /// Tests pass an in-memory [executor]; production opens the on-device file.
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'agroapp',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 1;
}
