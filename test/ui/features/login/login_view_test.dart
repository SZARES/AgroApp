import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/domain/models/app_user.dart';
import 'package:hackathon/domain/models/auth_failure.dart';
import 'package:hackathon/domain/models/user_role.dart';
import 'package:hackathon/ui/features/auth/view_models/auth_view_model.dart';
import 'package:hackathon/ui/features/login/view_models/login_view_model.dart';
import 'package:hackathon/ui/features/login/views/login_view.dart';
import 'package:hackathon/ui/features/staff_home/views/staff_home_view.dart';
import 'package:hackathon/utils/result.dart';

import '../../../testing/fakes.dart';

const _technician = AppUser(
  id: 'u2',
  email: 'tec@correo.pe',
  fullName: 'Luis',
  role: UserRole.technician,
  status: UserStatus.active,
);

void main() {
  late FakeAuthRepository repository;
  late LoginViewModel viewModel;

  setUp(() {
    repository = FakeAuthRepository(signInResult: const Result.ok(_technician));
    viewModel = LoginViewModel(
      authViewModel: AuthViewModel(
        authRepository: repository,
        requestSync: () async => null,
      ),
    );
  });

  group('LoginViewModel', () {
    test('rejects a malformed email without calling the backend', () async {
      expect(await viewModel.signIn('no-es-correo', 'secreto123'), isNull);
      expect(viewModel.error, LoginError.invalidEmail);
      expect(repository.signIns, isEmpty);
    });

    test('rejects an empty password', () async {
      expect(await viewModel.signIn('tec@correo.pe', ''), isNull);
      expect(viewModel.error, LoginError.missingPassword);
    });

    test('does not enforce a minimum password length on login', () async {
      expect(await viewModel.signIn('tec@correo.pe', 'a'), _technician);
    });

    test('returns the signed-in user', () async {
      expect(
        await viewModel.signIn(' tec@correo.pe ', 'secreto123'),
        _technician,
      );
      expect(viewModel.error, isNull);
    });

    final cases = {
      AuthFailure.invalidCredentials: LoginError.invalidCredentials,
      AuthFailure.inactiveAccount: LoginError.inactiveAccount,
      AuthFailure.noProfile: LoginError.noProfile,
      AuthFailure.offline: LoginError.offline,
      AuthFailure.unknown: LoginError.unknown,
    };
    for (final MapEntry(key: failure, value: expected) in cases.entries) {
      test('maps ${failure.name}', () async {
        repository.signInResult = Result.error(AuthFailureException(failure));

        expect(await viewModel.signIn('tec@correo.pe', 'secreto123'), isNull);
        expect(viewModel.error, expected);
      });
    }
  });

  group('LoginView', () {
    Future<List<AppUser>> pumpLogin(WidgetTester tester) async {
      final signedIn = <AppUser>[];
      await tester.pumpWidget(
        MaterialApp(
          home: LoginView(viewModel: viewModel, onSignedIn: signedIn.add),
        ),
      );
      return signedIn;
    }

    Future<void> fill(
      WidgetTester tester,
      String email,
      String password,
    ) async {
      await tester.enterText(find.byType(TextField).first, email);
      await tester.enterText(find.byType(TextField).last, password);
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
    }

    testWidgets('valid credentials report the signed-in user', (tester) async {
      final signedIn = await pumpLogin(tester);

      await fill(tester, 'tec@correo.pe', 'secreto123');

      expect(signedIn.single.role, UserRole.technician);
    });

    testWidgets('a bad email shows a plain-language error', (tester) async {
      final signedIn = await pumpLogin(tester);

      await fill(tester, 'ana', 'secreto123');

      expect(
        find.text('Escriba un correo válido, por ejemplo nombre@correo.com'),
        findsOneWidget,
      );
      expect(signedIn, isEmpty);
    });

    testWidgets('wrong credentials show an error and stay', (tester) async {
      repository.signInResult = const Result.error(
        AuthFailureException(AuthFailure.invalidCredentials),
      );
      final signedIn = await pumpLogin(tester);

      await fill(tester, 'tec@correo.pe', 'mala');

      expect(
        find.text('El correo o la contraseña no son correctos'),
        findsOneWidget,
      );
      expect(signedIn, isEmpty);
    });

    testWidgets('offline sign-in explains that a connection is needed', (
      tester,
    ) async {
      repository.signInResult = const Result.error(
        AuthFailureException(AuthFailure.offline),
      );
      await pumpLogin(tester);

      await fill(tester, 'tec@correo.pe', 'secreto123');

      expect(find.textContaining('necesita conexión'), findsOneWidget);
    });

    testWidgets('the eye button shows and hides the password', (tester) async {
      await pumpLogin(tester);
      TextField password() =>
          tester.widget<TextField>(find.byType(TextField).last);

      expect(password().obscureText, isTrue);
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();

      expect(password().obscureText, isFalse);
    });
  });

  group('StaffHomeView', () {
    for (final role in [
      UserRole.technician,
      UserRole.supervisor,
      UserRole.admin,
    ]) {
      testWidgets('${role.name} sees its own panel', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: StaffHomeView(role: role, onSignOut: () {}),
          ),
        );

        expect(find.text(StaffHomeView.titleFor(role)), findsOneWidget);
      });
    }
  });
}
