import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/data/sync/sync_engine.dart';
import 'package:hackathon/ui/core/theme/app_theme.dart';
import 'package:hackathon/ui/core/widgets/primary_action_button.dart';
import 'package:hackathon/ui/features/activity_log/views/activity_log_view.dart';
import 'package:hackathon/ui/features/assistance/views/assistance_view.dart';
import 'package:hackathon/ui/features/harvest/views/harvest_view.dart';
import 'package:hackathon/ui/features/home/view_models/home_view_model.dart';
import 'package:hackathon/ui/features/home/views/home_view.dart';
import 'package:hackathon/ui/features/incident_report/views/incident_report_view.dart';

import '../../../testing/fakes.dart';

void main() {
  late AppDatabase database;
  late OutboxRepository repository;
  late FakeSyncService syncService;
  late FakeConnectivityService connectivity;

  setUp(() {
    database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repository = OutboxRepository(database);
    syncService = FakeSyncService();
    connectivity = FakeConnectivityService(online: false);
  });

  tearDown(() async {
    await connectivity.close();
    await database.close();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    final viewModel = HomeViewModel(
      outboxRepository: repository,
      syncEngine: SyncEngine(
        repository: repository,
        syncService: syncService,
        connectivity: connectivity,
      ),
    );
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeView(viewModel: viewModel),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the three main actions and the assistance entry', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.byType(PrimaryActionButton), findsNWidgets(3));
    expect(find.text('Registrar lo que hice'), findsOneWidget);
    expect(find.text('Reportar un problema'), findsOneWidget);
    expect(find.text('Registrar cosecha'), findsOneWidget);
    expect(find.text('Mis asistencias'), findsOneWidget);
    expect(find.text('Todo guardado'), findsOneWidget);
  });

  testWidgets('sync indicator reflects the pending count', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 3; i++) {
        await repository.enqueue(tableName: 'activities', payload: const {});
      }
    });

    await pumpHome(tester);

    expect(find.text('3 registros por enviar'), findsOneWidget);
    expect(find.text('Todo guardado'), findsNothing);
  });

  testWidgets('sending now uploads pending records once online', (
    tester,
  ) async {
    await tester.runAsync(
      () => repository.enqueue(tableName: 'activities', payload: const {}),
    );
    await pumpHome(tester);
    expect(find.text('1 registro por enviar'), findsOneWidget);

    connectivity.online = true;
    await tester.tap(find.text('Enviar ahora'));
    await tester.pumpAndSettle();

    expect(syncService.batches, hasLength(1));
    expect(find.text('Todo guardado'), findsOneWidget);
  });

  final destinations = <String, Type>{
    'Registrar lo que hice': ActivityLogView,
    'Reportar un problema': IncidentReportView,
    'Registrar cosecha': HarvestView,
    'Mis asistencias': AssistanceView,
  };

  for (final MapEntry(key: label, value: view) in destinations.entries) {
    testWidgets('tapping "$label" opens $view', (tester) async {
      await pumpHome(tester);

      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.byType(view), findsOneWidget);
      expect(find.text('Próximamente'), findsOneWidget);
    });
  }
}
