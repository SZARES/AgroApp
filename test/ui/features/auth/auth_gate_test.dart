import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/domain/models/app_user.dart';
import 'package:hackathon/domain/models/user_role.dart';
import 'package:hackathon/ui/core/widgets/three_panel_scaffold.dart';
import 'package:hackathon/ui/features/auth/view_models/auth_view_model.dart';
import 'package:hackathon/ui/features/auth/views/auth_gate.dart';
import 'package:hackathon/ui/features/auth/views/splash_view.dart';
import 'package:hackathon/ui/features/console/views/console_view.dart';
import 'package:hackathon/utils/result.dart';

import '../../../testing/fakes.dart';

AppUser _user(UserRole role) => AppUser(
  id: 'u1',
  email: 'a@b.pe',
  fullName: 'Ana Quispe',
  role: role,
  status: UserStatus.active,
);

void main() {
  late FakeAuthRepository repository;
  late AuthViewModel viewModel;
  var signOuts = 0;

  setUp(() {
    repository = FakeAuthRepository();
    viewModel = AuthViewModel(
      authRepository: repository,
      requestSync: () async => null,
    );
    signOuts = 0;
  });

  Future<void> pumpGate(
    WidgetTester tester, {
    required Size size,
    UserRole? role,
    bool? web,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (role != null) {
      repository.restoreResult = Result.ok(_user(role));
      await viewModel.bootstrap();
    }
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          viewModel: viewModel,
          forceWebLayout: web,
          onSignOut: () => signOuts++,
          signedOutBuilder: (_) => const Text('SIGNED_OUT'),
          farmerBuilder: (_, _, _) =>
              const SizedBox.expand(key: Key('farmer'), child: Text('FARMER')),
          technicianMobileBuilder: (_, _, _) => const Text('TECH_MOBILE'),
          consoleBuilder: (_, user, onSignOut) =>
              ConsoleView(user: user, onSignOut: onSignOut),
        ),
      ),
    );
  }

  const phone = Size(400, 800);
  const desktop = Size(1366, 768);

  testWidgets('shows the splash while the session is unknown', (tester) async {
    await pumpGate(tester, size: phone);

    expect(find.byType(SplashView), findsOneWidget);
  });

  testWidgets('signed out shows the signed-out flow', (tester) async {
    await viewModel.bootstrap();
    await pumpGate(tester, size: phone);

    expect(find.text('SIGNED_OUT'), findsOneWidget);
  });

  testWidgets('a farmer gets the mobile column, capped on wide screens', (
    tester,
  ) async {
    await pumpGate(tester, size: desktop, role: UserRole.farmer);

    expect(find.text('FARMER'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('farmer'))).width,
      AuthGate.farmerMaxWidth,
    );
  });

  testWidgets('a technician on a phone gets the mobile home', (tester) async {
    await pumpGate(tester, size: phone, role: UserRole.technician);

    expect(find.text('TECH_MOBILE'), findsOneWidget);
    expect(find.byType(ConsoleView), findsNothing);
  });

  testWidgets('a technician on a wide screen gets the console', (tester) async {
    await pumpGate(tester, size: desktop, role: UserRole.technician);

    expect(find.byType(ConsoleView), findsOneWidget);
    expect(find.text('TECH_MOBILE'), findsNothing);
  });

  testWidgets('a technician on the web always gets the console', (
    tester,
  ) async {
    await pumpGate(tester, size: phone, role: UserRole.technician, web: true);

    expect(find.byType(ConsoleView), findsOneWidget);
  });

  for (final role in [UserRole.supervisor, UserRole.admin]) {
    testWidgets('${role.name} on a wide screen gets the console', (
      tester,
    ) async {
      await pumpGate(tester, size: desktop, role: role);

      expect(find.byType(ConsoleView), findsOneWidget);
      expect(find.byType(DesktopHintView), findsNothing);
    });

    testWidgets('${role.name} on a phone sees the hint and can continue', (
      tester,
    ) async {
      await pumpGate(tester, size: phone, role: role);

      expect(find.text(DesktopHintView.message), findsOneWidget);

      await tester.tap(find.text('Continuar aquí'));
      await tester.pumpAndSettle();

      expect(find.byType(ConsoleView), findsOneWidget);
    });
  }

  testWidgets('the phone hint offers sign-out', (tester) async {
    await pumpGate(tester, size: phone, role: UserRole.supervisor);

    await tester.tap(find.text('Cerrar sesión'));

    expect(signOuts, 1);
  });

  testWidgets('console modules follow the role', (tester) async {
    await pumpGate(tester, size: desktop, role: UserRole.supervisor);

    for (final label in ['Inicio', 'Territorio', 'Equipo', 'Reportes']) {
      expect(find.byTooltip(label), findsOneWidget);
    }
    expect(find.byTooltip('Administración'), findsNothing);
    expect(
      find.text('Este módulo se activa en la siguiente etapa'),
      findsOneWidget,
    );
  });

  testWidgets('console sidebar opens a module and offers sign-out', (
    tester,
  ) async {
    await pumpGate(tester, size: desktop, role: UserRole.admin);

    await tester.tap(find.byTooltip('Administración'));
    await tester.pump();
    expect(find.text('Administración'), findsWidgets);

    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    expect(signOuts, 1);
  });

  test('breakpoint helper matches the documented 900 px', () {
    expect(ThreePanelScaffold.isWide(899), isFalse);
    expect(ThreePanelScaffold.isWide(900), isTrue);
  });
}
