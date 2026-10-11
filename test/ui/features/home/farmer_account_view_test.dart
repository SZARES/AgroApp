import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/data/sync/sync_engine.dart';
import 'package:hackathon/ui/core/theme/app_theme.dart';
import 'package:hackathon/ui/features/home/view_models/home_view_model.dart';
import 'package:hackathon/ui/features/home/views/farmer_account_view.dart';
import 'package:hackathon/ui/features/home/views/home_view.dart';

import '../../../testing/fakes.dart';
import '../../../testing/home_fakes.dart';

void main() {
  late AppDatabase database;
  late OutboxRepository repository;
  late FakeConnectivityService connectivity;

  setUp(() {
    database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repository = OutboxRepository(database);
    connectivity = FakeConnectivityService(online: true);
  });

  tearDown(() async {
    await connectivity.close();
    await database.close();
  });

  testWidgets('account screen shows name, sync status and sign out', (
    tester,
  ) async {
    var signedOut = false;
    final viewModel = HomeViewModel(
      outboxRepository: repository,
      homeRepository: FakeHomeRepository(),
      syncEngine: SyncEngine(
        repository: repository,
        localStore: LocalStore(database, repository),
        syncService: FakeSyncService(),
        connectivity: connectivity,
      ),
      fullName: 'Nelson Talledo',
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FarmerAccountView(
          viewModel: viewModel,
          onSignOut: () => signedOut = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nelson Talledo'), findsOneWidget);
    expect(find.text('Agricultor'), findsOneWidget);
    expect(find.text('Todo guardado'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
  });

  testWidgets('home account button opens Mi cuenta', (tester) async {
    final viewModel = HomeViewModel(
      outboxRepository: repository,
      homeRepository: FakeHomeRepository(),
      syncEngine: SyncEngine(
        repository: repository,
        localStore: LocalStore(database, repository),
        syncService: FakeSyncService(),
        connectivity: connectivity,
      ),
      fullName: 'Rosa María',
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
          parcelBuilder: (_) => const SizedBox(),
          activityBuilder: (_) => const SizedBox(),
          harvestBuilder: (_) => const SizedBox(),
          reportBuilder: (_) => const SizedBox(),
          caseBuilder: (_) => const SizedBox(),
          calendarBuilder: (_) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('R'));
    await tester.pumpAndSettle();

    expect(find.text('Mi cuenta'), findsOneWidget);
    expect(find.text('Rosa María'), findsOneWidget);
  });
}
