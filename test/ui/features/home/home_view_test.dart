import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/data/sync/sync_engine.dart';
import 'package:hackathon/domain/models/home_summary.dart';
import 'package:hackathon/domain/models/incident_status.dart';
import 'package:hackathon/ui/core/theme/app_theme.dart';
import 'package:hackathon/ui/core/widgets/primary_action_button.dart';
import 'package:hackathon/ui/features/activity_log/views/activity_log_view.dart';
import 'package:hackathon/ui/features/assistance/views/assistance_view.dart';
import 'package:hackathon/ui/features/harvest/views/harvest_view.dart';
import 'package:hackathon/ui/features/home/view_models/home_view_model.dart';
import 'package:hackathon/ui/features/home/views/home_view.dart';
import 'package:hackathon/ui/features/incident_report/views/incident_report_view.dart';

import '../../../testing/fakes.dart';
import '../../../testing/home_fakes.dart';

void main() {
  late AppDatabase database;
  late OutboxRepository repository;
  late FakeSyncService syncService;
  late FakeConnectivityService connectivity;
  late FakeHomeRepository homeRepository;

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
    homeRepository = FakeHomeRepository();
  });

  tearDown(() async {
    await connectivity.close();
    await database.close();
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    String fullName = 'Rosa María Pérez',
  }) async {
    final viewModel = HomeViewModel(
      outboxRepository: repository,
      homeRepository: homeRepository,
      syncEngine: SyncEngine(
        repository: repository,
        localStore: LocalStore(database, repository),
        syncService: syncService,
        connectivity: connectivity,
      ),
      fullName: fullName,
    );
    addTearDown(viewModel.dispose);
    tester.view.physicalSize = const Size(600, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeView(
          viewModel: viewModel,
          parcelBuilder: (_) => const Scaffold(body: Text('Pantalla parcela')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'greets the farmer by first name with exactly three main actions',
    (tester) async {
      await pumpHome(tester);

      expect(find.text('Hola, Rosa'), findsOneWidget);
      expect(find.byType(PrimaryActionButton), findsNWidgets(3));
      expect(find.text('Registrar actividad'), findsOneWidget);
      expect(find.text('Reportar problema'), findsOneWidget);
      expect(find.text('Registrar cosecha'), findsOneWidget);
      expect(find.text('Mis asistencias'), findsOneWidget);
      expect(find.text('Todo guardado'), findsOneWidget);
    },
  );

  testWidgets('shows a plain greeting when the profile has no name', (
    tester,
  ) async {
    await pumpHome(tester, fullName: '');

    expect(find.text('Hola'), findsOneWidget);
  });

  testWidgets('shows friendly empty states without local records', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.scrollUntilVisible(
      find.text('Aún no registra cosechas'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Toque aquí para agregar su terreno'), findsOneWidget);
    expect(find.text('Aún no lo registra'), findsOneWidget);
    expect(find.text('Por ahora no tiene recomendaciones'), findsOneWidget);
    expect(find.text('Sin problemas activos'), findsOneWidget);
    expect(find.text('Aún no registra cosechas'), findsOneWidget);
  });

  testWidgets('renders the parcel and the utility cards from local data', (
    tester,
  ) async {
    homeRepository = FakeHomeRepository(
      HomeSummary(
        parcelName: 'Campo del pozo',
        parcelCount: 2,
        hasLocation: true,
        locationLabel: 'Morropón · La Matanza',
        lastFertilization: DateTime(2026, 5, 5),
        nextRecommendation: 'Podar ramas secas',
        activeIncident: IncidentStatus.visitScheduled,
        harvestCount: 2,
        productionKg: 150.5,
      ),
    );

    await pumpHome(tester);
    await tester.scrollUntilVisible(
      find.text('150,5 kg'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Campo del pozo y 1 más'), findsOneWidget);
    expect(find.text('Morropón · La Matanza'), findsOneWidget);
    expect(find.text('5 de mayo de 2026'), findsOneWidget);
    expect(find.text('Podar ramas secas'), findsOneWidget);
    expect(find.text('Visita programada'), findsOneWidget);
    expect(find.text('150,5 kg'), findsOneWidget);
  });

  testWidgets('updates live when the local summary changes', (tester) async {
    await pumpHome(tester);
    expect(find.text('Mi parcela'), findsOneWidget);

    homeRepository.emit(const HomeSummary(parcelName: 'Campo nuevo'));
    await tester.pumpAndSettle();

    expect(find.text('Campo nuevo'), findsOneWidget);
  });

  testWidgets('tapping the parcel card opens the parcel screen', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.text('Mi parcela'));
    await tester.pumpAndSettle();

    expect(find.text('Pantalla parcela'), findsOneWidget);
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
    'Registrar actividad': ActivityLogView,
    'Reportar problema': IncidentReportView,
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
    });
  }
}
