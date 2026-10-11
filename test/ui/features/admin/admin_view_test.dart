import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/admin_repository.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/domain/models/app_user.dart';
import 'package:hackathon/domain/models/user_role.dart';
import 'package:hackathon/ui/features/admin/views/admin_view.dart';
import 'package:hackathon/ui/features/console/console_modules.dart';
import 'package:hackathon/ui/features/console/views/console_view.dart';
import 'package:provider/provider.dart';

import '../../../testing/admin_fakes.dart';
import '../../../testing/fakes.dart';

AppUser _user(UserRole role) => AppUser(
  id: 'admin-1',
  email: 'admin@aider.pe',
  fullName: 'Admin',
  role: role,
  status: UserStatus.active,
);

void main() {
  late AppDatabase database;
  late LocalStore store;
  late AdminRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = LocalStore(database, OutboxRepository(database));
    repository = DefaultAdminRepository(
      service: FakeAdminService(),
      store: store,
      connectivity: FakeConnectivityService(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpConsole(WidgetTester tester, UserRole role) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<AdminRepository>.value(
        value: repository,
        child: MaterialApp(
          home: ConsoleView(user: _user(role), onSignOut: () {}),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  /// Unmounts the tree and lets Drift's stream cleanup timers run.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  test('only the admin role gets the admin module', () {
    for (final role in UserRole.values) {
      final ids = ConsoleModules.forRole(role).map((m) => m.id);
      expect(ids.contains('admin'), role == UserRole.admin, reason: role.name);
    }
  });

  testWidgets('the admin view refuses non-admins', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminView(
          user: _user(UserRole.supervisor),
          repository: repository,
          panelsBuilder: (list, main) => Row(
            children: [
              list,
              Expanded(child: main),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Sin acceso'), findsOneWidget);
    expect(find.text('Crear usuario'), findsNothing);
  });

  testWidgets('a supervisor console has no admin entry', (tester) async {
    await pumpConsole(tester, UserRole.supervisor);

    expect(find.byTooltip('Administración'), findsNothing);
    await finish(tester);
  });

  testWidgets('admin users list renders from the replica', (tester) async {
    await tester.runAsync(() async {
      await store.applyServerRows('profiles', [
        {
          'id': 'u1',
          'full_name': 'Ana Quispe',
          'email': '71226316@agricultores.agroapp',
          'role': 'farmer',
          'status': 'active',
          'updated_at': '2026-01-01T00:00:00Z',
        },
        {
          'id': 'u2',
          'full_name': 'Luis Rojas',
          'email': 'luis@aider.pe',
          'role': 'technician',
          'status': 'inactive',
          'updated_at': '2026-01-01T00:00:00Z',
        },
      ]);
      await store.applyServerRows('farmers', [
        {
          'id': 'f1',
          'user_id': 'u1',
          'dni': '71226316',
          'updated_at': '2026-01-01T00:00:00Z',
        },
      ]);
    });
    await pumpConsole(tester, UserRole.admin);
    await tester.tap(find.byTooltip('Administración'));
    await settle(tester);

    expect(find.text('Ana Quispe'), findsOneWidget);
    expect(find.text('Luis Rojas'), findsOneWidget);
    expect(find.text('DNI 71226316'), findsOneWidget);
    expect(find.text('Agricultor'), findsWidgets);
    expect(find.text('Inactivo'), findsOneWidget);
    expect(find.text('Crear usuario'), findsOneWidget);

    await tester.tap(find.text('Ana Quispe'));
    await settle(tester);
    expect(find.text('Entra con su DNI'), findsOneWidget);
    expect(
      find.text('El rol no se puede cambiar; cree una cuenta nueva.'),
      findsOneWidget,
    );
    await finish(tester);
  });

  testWidgets('create-user form adapts to the chosen role', (tester) async {
    await pumpConsole(tester, UserRole.admin);
    await tester.tap(find.byTooltip('Administración'));
    await settle(tester);

    await tester.tap(find.text('Crear usuario'));
    await settle(tester);
    expect(find.byKey(const ValueKey('field_dni')), findsNothing);
    expect(find.byKey(const ValueKey('field_email')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('role_farmer')));
    await settle(tester);
    expect(find.byKey(const ValueKey('field_dni')), findsOneWidget);
    expect(find.byKey(const ValueKey('field_email')), findsNothing);
    expect(find.text('Zonas de trabajo'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('role_technician')));
    await settle(tester);
    expect(find.byKey(const ValueKey('field_dni')), findsNothing);
    expect(find.byKey(const ValueKey('field_email')), findsOneWidget);
    expect(find.text('Zonas de trabajo'), findsOneWidget);
    expect(find.text('Generar contraseña'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('catalog sections show an honest empty state and CTA', (
    tester,
  ) async {
    await pumpConsole(tester, UserRole.admin);
    await tester.tap(find.byTooltip('Administración'));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('admin_section_switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cultivos').last);
    await settle(tester);

    expect(find.text('Agregar cultivo'), findsOneWidget);
    expect(find.textContaining('Todavía no hay cultivos'), findsOneWidget);

    await tester.tap(find.text('Agregar cultivo'));
    await settle(tester);
    expect(find.text('Nuevo: cultivo'), findsOneWidget);
    expect(find.text('Unidades de cosecha permitidas'), findsOneWidget);
    await finish(tester);
  });
}
