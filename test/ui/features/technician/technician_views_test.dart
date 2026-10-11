import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/repositories/technician_repository.dart';
import 'package:hackathon/domain/models/app_user.dart';
import 'package:hackathon/domain/models/incident_status.dart';
import 'package:hackathon/domain/models/parcel.dart';
import 'package:hackathon/domain/models/technician_case.dart';
import 'package:hackathon/domain/models/technician_farmer.dart';
import 'package:hackathon/domain/models/user_role.dart';
import 'package:hackathon/ui/core/widgets/skeleton.dart';
import 'package:hackathon/ui/features/console/console_modules.dart';
import 'package:hackathon/ui/features/console/views/console_view.dart';
import 'package:hackathon/ui/features/technician/view_models/technician_case_view_model.dart';
import 'package:hackathon/ui/features/technician/view_models/technician_cases_view_model.dart';
import 'package:hackathon/ui/features/technician/view_models/technician_dashboard_view_model.dart';
import 'package:hackathon/ui/features/technician/view_models/technician_farmer_view_model.dart';
import 'package:hackathon/ui/features/technician/view_models/technician_farmers_view_model.dart';
import 'package:hackathon/ui/features/technician/views/technician_dashboard_view.dart';
import 'package:hackathon/ui/features/technician/views/technician_farmers_view.dart';
import 'package:hackathon/ui/features/technician/views/technician_home_view.dart';
import 'package:hackathon/ui/features/technician/views/technician_workspace.dart';
import 'package:provider/provider.dart';

import '../../../testing/technician_fakes.dart';

const _wide = Size(1280, 900);
const _phone = Size(400, 800);

const _rosa = TechnicianFarmer(
  id: 'f1',
  name: 'Rosa Quispe',
  phone: '999111222',
  communityName: 'Chulucanas',
  parcelCount: 2,
  openCaseCount: 1,
);

TechnicianFarmerDetail _rosaDetail() => TechnicianFarmerDetail(
  farmer: _rosa,
  parcels: const [
    Parcel(id: 'p1', name: 'Campo alto', areaHectares: 2, cropName: 'Limón'),
    Parcel(id: 'p2', name: 'Campo bajo'),
  ],
  cases: [fakeCase('c1', symptom: 'Plaga en hojas')],
  assistances: [
    FarmerAssistanceEntry(
      id: 'a1',
      date: DateTime(2026, 9, 10),
      topic: 'Poda',
      status: 'completed',
      isPending: false,
    ),
  ],
  recommendations: const RecommendationCounts(issued: 2, confirmed: 1),
);

void main() {
  late FakeTechnicianRepository repository;

  setUp(() => repository = FakeTechnicianRepository());

  void useSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget twoPanels(Widget list, Widget main) => Row(
    children: [
      SizedBox(width: 340, child: list),
      Expanded(child: main),
    ],
  );

  group('alert workspace', () {
    late TechnicianCasesViewModel cases;

    Future<void> pumpWorkspace(WidgetTester tester) async {
      useSize(tester, _wide);
      cases = TechnicianCasesViewModel(repository: repository);
      addTearDown(cases.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TechnicianWorkspace(
              viewModel: cases,
              caseViewModelBuilder: (id) =>
                  TechnicianCaseViewModel(repository: repository, caseId: id),
              panelsBuilder: twoPanels,
            ),
          ),
        ),
      );
    }

    testWidgets('shows a skeleton, not a spinner, while loading', (
      tester,
    ) async {
      await pumpWorkspace(tester);

      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      repository.cases.add([fakeCase('a', symptom: 'Hojas amarillas')]);
      await tester.pump();
      await tester.pump();

      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('Hojas amarillas'), findsOneWidget);
    });

    testWidgets('filter chips narrow the list and show their counts', (
      tester,
    ) async {
      await pumpWorkspace(tester);
      repository.cases.add([
        fakeCase('a', symptom: 'Caso urgente', priority: CasePriority.high),
        fakeCase('b', symptom: 'Caso normal'),
        fakeCase(
          'c',
          symptom: 'Caso cerrado',
          status: IncidentStatus.closed,
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Todos (3)'), findsOneWidget);
      expect(find.text('Urgentes (1)'), findsOneWidget);
      expect(find.text('Cerrados (1)'), findsOneWidget);

      await tester.tap(find.text('Urgentes (1)'));
      await tester.pump();
      expect(find.text('Caso urgente'), findsOneWidget);
      expect(find.text('Caso normal'), findsNothing);

      // The filters are one scrollable line; the last one may be off screen.
      await tester.ensureVisible(find.text('Cerrados (1)'));
      await tester.pump();
      await tester.tap(find.text('Cerrados (1)'));
      await tester.pump();
      expect(find.text('Caso cerrado'), findsOneWidget);
      expect(find.text('Caso urgente'), findsNothing);
      // The open total is not affected by the filter.
      expect(find.text('2 casos abiertos'), findsOneWidget);
    });

    testWidgets('a filter without matches explains it', (tester) async {
      await pumpWorkspace(tester);
      repository.cases.add([fakeCase('a')]);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Urgentes (0)'));
      await tester.pump();

      expect(find.text('No hay casos con este filtro.'), findsOneWidget);
    });

    testWidgets('a failed load shows a friendly message', (tester) async {
      await pumpWorkspace(tester);
      await tester.pump();
      repository.cases.addError(StateError('boom'));
      await tester.pump();
      await tester.pump();

      expect(find.text('No pudimos leer los casos'), findsOneWidget);
    });
  });

  group('dashboard', () {
    testWidgets('shows skeleton cards, then KPIs and cases to attend', (
      tester,
    ) async {
      useSize(tester, _wide);
      final cases = TechnicianCasesViewModel(repository: repository);
      final dashboard = TechnicianDashboardViewModel(repository: repository);
      addTearDown(cases.dispose);
      addTearDown(dashboard.dispose);
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TechnicianDashboardBody(
              dashboard: dashboard,
              cases: cases,
              onOpenCase: (id) => opened = id,
            ),
          ),
        ),
      );

      expect(find.byType(KpiGridSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      repository.kpis.add(
        const TechnicianKpis(
          openAlerts: 4,
          urgentAlerts: 2,
          scheduledVisits: 3,
          attendedCases: 5,
          closedCases: 6,
          activeFarmers: 9,
          recommendationsIssued: 8,
          recommendationsConfirmed: 5,
          avgResponseDays: 1.5,
        ),
      );
      repository.cases.add([
        fakeCase('a', symptom: 'Roya', priority: CasePriority.high),
        fakeCase('done', symptom: 'Ya atendido', status: IncidentStatus.attended),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.byType(KpiGridSkeleton), findsNothing);
      for (final label in [
        'Alertas abiertas',
        'Urgentes',
        'Visitas programadas',
        'Atendidos',
        'Agricultores activos',
        'Recomendaciones confirmadas',
        'Tiempo medio de atención',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('5 de 8'), findsOneWidget);
      expect(find.text('1,5 días'), findsOneWidget);
      expect(find.text('Roya'), findsOneWidget);
      expect(find.text('Ya atendido'), findsNothing);

      await tester.tap(find.text('Roya'));
      expect(opened, 'a');
    });

    test('formats the average response time', () {
      expect(formatAverageResponse(null), 'Sin datos');
      expect(formatAverageResponse(0.01), 'Menos de 1 h');
      expect(formatAverageResponse(0.25), '6 h');
      expect(formatAverageResponse(1), '1 día');
      expect(formatAverageResponse(2.34), '2,3 días');
    });
  });

  group('farmers workspace', () {
    late TechnicianFarmersViewModel farmers;
    String? openedCase;

    Future<void> pumpFarmers(WidgetTester tester) async {
      useSize(tester, _wide);
      farmers = TechnicianFarmersViewModel(repository: repository);
      addTearDown(farmers.dispose);
      openedCase = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TechnicianFarmersWorkspace(
              viewModel: farmers,
              farmerViewModelBuilder: (id) => TechnicianFarmerViewModel(
                repository: repository,
                farmerId: id,
              ),
              onOpenCase: (id) => openedCase = id,
              panelsBuilder: twoPanels,
            ),
          ),
        ),
      );
    }

    testWidgets('lists farmers after a skeleton and asks to pick one', (
      tester,
    ) async {
      await pumpFarmers(tester);
      expect(find.byType(SkeletonList), findsOneWidget);

      repository.farmers.add(const [_rosa]);
      await tester.pump();
      await tester.pump();

      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('1 agricultor'), findsOneWidget);
      expect(find.text('Rosa Quispe'), findsOneWidget);
      expect(find.text('Chulucanas · 2 parcelas'), findsOneWidget);
      expect(find.text('1 caso abierto'), findsOneWidget);
      expect(find.text('Elija un agricultor'), findsOneWidget);
    });

    testWidgets('the farmer file shows parcels, cases and assistances', (
      tester,
    ) async {
      await pumpFarmers(tester);
      repository.farmers.add(const [_rosa]);
      repository.farmerFeed('f1').add(_rosaDetail());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Rosa Quispe'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SkeletonDetail), findsNothing);

      expect(find.text('999111222'), findsOneWidget);
      expect(find.text('Campo alto'), findsOneWidget);
      expect(find.text('Plaga en hojas'), findsOneWidget);
      expect(find.text('Poda'), findsOneWidget);
      expect(find.text('1 de 2 recomendaciones aplicadas'), findsOneWidget);
      expect(find.text('Registrar asistencia'), findsOneWidget);

      await tester.tap(find.text('Plaga en hojas'));
      expect(openedCase, 'c1');
    });

    testWidgets('registers an assistance on the chosen parcel', (tester) async {
      await pumpFarmers(tester);
      repository.farmers.add(const [_rosa]);
      repository.catalog.add(const [
        AssistanceCategoryOption(id: 'cat1', name: 'Visita técnica'),
      ]);
      repository.farmerFeed('f1').add(_rosaDetail());
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Rosa Quispe'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Registrar asistencia'));
      await tester.pumpAndSettle();
      expect(find.text('Parcela'), findsOneWidget);

      // Second parcel.
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Campo bajo').last);
      await tester.pumpAndSettle();
      // Type of assistance.
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visita técnica').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Observación'),
        'Revisé el riego',
      );
      await tester.pump();
      await tester.tap(find.text('Guardar asistencia'));
      await tester.pumpAndSettle();

      final call = repository.fieldAssistances.single;
      expect(call.farmerId, 'f1');
      expect(call.parcelId, 'p2');
      expect(call.draft.categoryId, 'cat1');
      expect(call.draft.observation, 'Revisé el riego');
      expect(
        find.text('Guardado en el dispositivo. Se enviará con conexión.'),
        findsOneWidget,
      );
    });

    testWidgets('a farmer with one parcel is not asked which one', (
      tester,
    ) async {
      await pumpFarmers(tester);
      repository.farmers.add(const [_rosa]);
      repository.farmerFeed('f1').add(
        TechnicianFarmerDetail(
          farmer: _rosa,
          parcels: const [Parcel(id: 'p1', name: 'Única')],
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Rosa Quispe'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Registrar asistencia'));
      await tester.pumpAndSettle();

      expect(find.text('Parcela'), findsNothing);
      expect(find.text('Todavía no hay asistencias.'), findsOneWidget);
    });
  });

  group('console routing', () {
    AppUser user(UserRole role) => AppUser(
      id: 'u1',
      email: 'a@b.pe',
      fullName: 'Tecnico Uno',
      role: role,
      status: UserStatus.active,
    );

    Future<void> pumpConsole(WidgetTester tester) async {
      useSize(tester, _wide);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<TechnicianRepository>.value(value: repository),
            ChangeNotifierProvider(
              create: (_) => TechnicianCasesViewModel(repository: repository),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  TechnicianDashboardViewModel(repository: repository),
            ),
            ChangeNotifierProvider(
              create: (_) => TechnicianFarmersViewModel(repository: repository),
            ),
          ],
          child: MaterialApp(
            home: ConsoleView(user: user(UserRole.technician), onSignOut: () {}),
          ),
        ),
      );
    }

    test('technician modules have no dead ends', () {
      expect(
        ConsoleModules.forRole(UserRole.technician).map((m) => m.id),
        ['home', 'farmers', 'alerts'],
      );
      // Admin keeps parcels and calendar.
      final admin = ConsoleModules.forRole(UserRole.admin).map((m) => m.id);
      expect(admin, containsAll(['parcels', 'calendar']));
      expect(admin, isNot(contains('farmers')));
    });

    testWidgets('navigates home, farmers and alerts', (tester) async {
      await pumpConsole(tester);
      repository.kpis.add(const TechnicianKpis(openAlerts: 1));
      repository.cases.add([fakeCase('a', symptom: 'Roya')]);
      repository.farmers.add(const [_rosa]);
      await tester.pump();
      await tester.pump();

      expect(find.byTooltip('Calendario'), findsNothing);
      expect(find.byTooltip('Parcelas'), findsNothing);
      expect(find.text('Para atender hoy'), findsOneWidget);

      await tester.tap(find.byTooltip('Agricultores'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Rosa Quispe'), findsOneWidget);
      expect(find.text('Elija un agricultor'), findsOneWidget);

      await tester.tap(find.byTooltip('Alertas'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Urgentes (0)'), findsOneWidget);
      expect(find.text('Roya'), findsOneWidget);
    });

    testWidgets('a dashboard case opens in the alerts module', (tester) async {
      await pumpConsole(tester);
      repository.kpis.add(const TechnicianKpis());
      repository.cases.add([fakeCase('a', symptom: 'Roya')]);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Roya'));
      await tester.pump();
      await tester.pump();

      // Now in the alerts module with the filter bar and the case selected.
      expect(find.text('Todos (1)'), findsOneWidget);
      expect(find.text('No encontramos este caso'), findsOneWidget);
    });
  });

  group('phone home', () {
    testWidgets('has four sections and opens a farmer file', (tester) async {
      useSize(tester, _phone);
      final cases = TechnicianCasesViewModel(repository: repository);
      final dashboard = TechnicianDashboardViewModel(repository: repository);
      final farmers = TechnicianFarmersViewModel(repository: repository);
      addTearDown(cases.dispose);
      addTearDown(dashboard.dispose);
      addTearDown(farmers.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: TechnicianHomeView(
            viewModel: cases,
            dashboard: dashboard,
            farmers: farmers,
            caseBuilder: (id) => Text('CASE $id'),
            farmerBuilder: (id) => Text('FARMER $id'),
            onSignOut: () {},
          ),
        ),
      );
      repository.kpis.add(const TechnicianKpis(openAlerts: 2));
      repository.cases.add([fakeCase('a', symptom: 'Roya')]);
      repository.farmers.add(const [_rosa]);
      await tester.pump();
      await tester.pump();

      expect(find.byType(NavigationDestination), findsNWidgets(4));
      for (final label in ['Inicio', 'Casos', 'Mapa', 'Agricultores']) {
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
      expect(find.text('Resumen de su zona'), findsOneWidget);

      await tester.tap(find.text('Casos').last);
      await tester.pump();
      expect(find.text('Todos (1)'), findsOneWidget);
      await tester.tap(find.text('Roya').last);
      await tester.pumpAndSettle();
      expect(find.text('CASE a'), findsOneWidget);
      Navigator.of(tester.element(find.text('CASE a'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Agricultores'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Rosa Quispe'));
      await tester.pumpAndSettle();
      expect(find.text('FARMER f1'), findsOneWidget);
    });
  });
}
