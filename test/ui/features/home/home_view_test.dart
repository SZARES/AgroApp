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
import 'package:hackathon/ui/features/home/view_models/home_view_model.dart';
import 'package:hackathon/ui/features/home/views/home_view.dart';

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
          onSignOut: () {},
          parcelBuilder: (_) => const Scaffold(body: Text('Pantalla parcela')),
          activityBuilder: (_) =>
              const Scaffold(body: Text('Pantalla actividad')),
          harvestBuilder: (_) => const Scaffold(body: Text('Pantalla cosecha')),
          reportBuilder: (_) => const Scaffold(body: Text('Pantalla reporte')),
          caseBuilder: (_) => const Scaffold(body: Text('Pantalla caso')),
          calendarBuilder: (_) =>
              const Scaffold(body: Text('Pantalla calendario')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'greets the farmer by first name with a 2x2 action grid',
    (tester) async {
      homeRepository = FakeHomeRepository(
        const HomeSummary(parcelName: 'Campo del pozo', parcelCount: 1),
      );
      await pumpHome(tester);

      expect(find.text('Hola, Rosa'), findsOneWidget);
      expect(find.text('Actividad'), findsOneWidget);
      expect(find.text('Problema'), findsOneWidget);
      expect(find.text('Cosecha'), findsOneWidget);
      expect(find.text('Terreno'), findsOneWidget);
      expect(find.text('Calendario'), findsOneWidget);
      expect(find.text('Mis asistencias'), findsNothing);
      expect(find.text('Mis reportes'), findsNothing);
      expect(find.text('Todo guardado'), findsNothing);
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    },
  );

  testWidgets('shows an upload sync icon when there are pending records', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await repository.enqueue(tableName: 'activities', payload: const {});
    });
    homeRepository = FakeHomeRepository(
      const HomeSummary(parcelName: 'Campo', parcelCount: 1),
    );
    await pumpHome(tester);

    expect(find.byIcon(Icons.cloud_upload), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done), findsNothing);
  });

  testWidgets('hides the actions that need a parcel until one exists', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Actividad'), findsNothing);
    expect(find.text('Problema'), findsNothing);
    expect(find.text('Cosecha'), findsNothing);
    expect(find.text('Terreno'), findsNothing);
    expect(
      find.textContaining('Agregue su terreno para registrar'),
      findsOneWidget,
    );

    homeRepository.emit(const HomeSummary(parcelName: 'Campo nuevo'));
    await tester.pumpAndSettle();

    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Problema'), findsOneWidget);
    expect(find.text('Cosecha'), findsOneWidget);
    expect(find.text('Terreno'), findsOneWidget);
    expect(find.text('Calendario'), findsOneWidget);
  });

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
    expect(find.text('Toque aquí para agregar su terreno'), findsOneWidget);

    await tester.tap(find.text('Resumen'));
    await tester.pumpAndSettle();

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
    expect(find.text('Campo del pozo y 1 más'), findsOneWidget);
    expect(find.text('Morropón · La Matanza'), findsOneWidget);

    await tester.tap(find.text('Resumen'));
    await tester.pumpAndSettle();

    expect(find.text('5 de mayo de 2026'), findsOneWidget);
    expect(find.text('Podar ramas secas'), findsOneWidget);
    expect(find.text('Visita programada'), findsOneWidget);
    expect(find.text('150,5 kg'), findsOneWidget);
  });

  testWidgets('carousel tabs switch between actions and summary', (
    tester,
  ) async {
    homeRepository = FakeHomeRepository(
      const HomeSummary(parcelName: 'Campo', parcelCount: 1),
    );
    await pumpHome(tester);

    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Su resumen'), findsNothing);

    await tester.tap(find.text('Resumen'));
    await tester.pumpAndSettle();
    expect(find.text('Su resumen'), findsOneWidget);
    expect(find.text('Actividad'), findsNothing);

    await tester.tap(find.text('Acciones'));
    await tester.pumpAndSettle();
    expect(find.text('Actividad'), findsOneWidget);
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

  final destinations = <String, String>{
    'Actividad': 'Pantalla actividad',
    'Problema': 'Pantalla reporte',
    'Cosecha': 'Pantalla cosecha',
    'Terreno': 'Pantalla parcela',
    'Calendario': 'Pantalla calendario',
  };

  for (final MapEntry(key: label, value: view) in destinations.entries) {
    testWidgets('tapping "$label" opens its screen', (tester) async {
      homeRepository = FakeHomeRepository(
        const HomeSummary(parcelName: 'Campo del pozo', parcelCount: 1),
      );
      await pumpHome(tester);

      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.text(view), findsOneWidget);
    });
  }
}
