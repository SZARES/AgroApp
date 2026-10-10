import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/repositories/auth_repository.dart';
import 'package:hackathon/domain/models/app_user.dart';
import 'package:hackathon/domain/models/user_role.dart';
import 'package:hackathon/ui/features/login/view_models/login_view_model.dart';
import 'package:hackathon/ui/features/login/views/login_view.dart';
import 'package:hackathon/ui/features/staff_home/views/staff_home_view.dart';

void main() {
  group('MockAuthRepository', () {
    const expectedRoles = {
      '71226316': UserRole.farmer,
      '75582477': UserRole.technician,
      '75501107': UserRole.supervisor,
      '71226320': UserRole.admin,
    };

    for (final MapEntry(key: dni, value: role) in expectedRoles.entries) {
      test('DNI $dni signs in as ${role.name}', () async {
        final viewModel = LoginViewModel(
          authRepository: const MockAuthRepository(),
        );

        final user = await viewModel.signIn(dni);

        expect(user?.role, role);
        expect(viewModel.error, isNull);
      });
    }
  });

  group('LoginViewModel', () {
    late LoginViewModel viewModel;

    setUp(() {
      viewModel = LoginViewModel(authRepository: const MockAuthRepository());
    });

    test('rejects a DNI that is not 8 digits', () async {
      expect(await viewModel.signIn('1234'), isNull);
      expect(viewModel.error, LoginError.invalidFormat);
    });

    test('rejects an unregistered DNI', () async {
      expect(await viewModel.signIn('00000000'), isNull);
      expect(viewModel.error, LoginError.unknownDni);
    });
  });

  group('LoginView', () {
    Future<List<AppUser>> pumpLogin(WidgetTester tester) async {
      final signedIn = <AppUser>[];
      await tester.pumpWidget(
        MaterialApp(
          home: LoginView(
            viewModel: LoginViewModel(
              authRepository: const MockAuthRepository(),
            ),
            onSignedIn: signedIn.add,
          ),
        ),
      );
      return signedIn;
    }

    testWidgets('a registered DNI reports the signed-in user', (tester) async {
      final signedIn = await pumpLogin(tester);

      await tester.enterText(find.byType(TextField), '75582477');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(signedIn.single.role, UserRole.technician);
    });

    testWidgets('an unregistered DNI shows an error and stays', (tester) async {
      final signedIn = await pumpLogin(tester);

      await tester.enterText(find.byType(TextField), '00000000');
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text('Este DNI no está registrado'), findsOneWidget);
      expect(signedIn, isEmpty);
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
