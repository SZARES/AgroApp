import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/domain/models/app_user.dart';
import 'package:hackathon/domain/models/auth_failure.dart';
import 'package:hackathon/domain/models/user_role.dart';
import 'package:hackathon/ui/features/auth/view_models/auth_view_model.dart';
import 'package:hackathon/utils/result.dart';

import '../../../testing/fakes.dart';

void main() {
  const farmer = AppUser(
    id: 'u1',
    email: 'ana@correo.pe',
    fullName: 'Ana',
    role: UserRole.farmer,
    status: UserStatus.active,
    farmerId: 'f1',
  );

  late FakeAuthRepository repository;
  late int syncRequests;

  AuthViewModel build() => AuthViewModel(
    authRepository: repository,
    requestSync: () async {
      syncRequests++;
      return null;
    },
  );

  setUp(() {
    repository = FakeAuthRepository();
    syncRequests = 0;
  });

  test('starts unknown', () {
    expect(build().state, isA<AuthUnknown>());
  });

  test('bootstrap without a session signs out', () async {
    final viewModel = build();

    await viewModel.bootstrap();

    expect(viewModel.state, isA<AuthSignedOut>());
    expect(syncRequests, 0);
  });

  test('bootstrap restores the user and syncs', () async {
    repository.restoreResult = const Result.ok(farmer);
    final viewModel = build();

    await viewModel.bootstrap();

    expect(viewModel.user, farmer);
    expect(syncRequests, 1);
  });

  test(
    'bootstrap failure leaves the user signed out with the reason',
    () async {
      repository.restoreResult = const Result.error(
        AuthFailureException(AuthFailure.inactiveAccount),
      );
      final viewModel = build();

      await viewModel.bootstrap();

      expect(viewModel.state, isA<AuthSignedOut>());
      expect(viewModel.restoreFailure, AuthFailure.inactiveAccount);
    },
  );

  test('signIn success signs in and forces a pull', () async {
    repository.signInResult = const Result.ok(farmer);
    final viewModel = build()..addListener(() {});

    final result = await viewModel.signIn('ana@correo.pe', 'secreto123');

    expect(result, isA<Ok<AppUser>>());
    expect(viewModel.user, farmer);
    expect(syncRequests, 1);
    expect(repository.signIns.single.email, 'ana@correo.pe');
  });

  test('signIn failure stays signed out', () async {
    final viewModel = build();
    await viewModel.bootstrap();

    final result = await viewModel.signIn('ana@correo.pe', 'mala');

    expect(result, isA<Error<AppUser>>());
    expect(viewModel.state, isA<AuthSignedOut>());
    expect(syncRequests, 0);
  });

  test('signOut blocked by unsent data keeps the session', () async {
    repository.signInResult = const Result.ok(farmer);
    repository.signOutResult = const Result.error(PendingDataBlocksSignOut(2));
    final viewModel = build();
    await viewModel.signIn('ana@correo.pe', 'secreto123');

    final result = await viewModel.signOut();

    expect(result, isA<Error<void>>());
    expect(viewModel.user, farmer);
  });

  test('forced signOut ends the session', () async {
    repository.signInResult = const Result.ok(farmer);
    final viewModel = build();
    await viewModel.signIn('ana@correo.pe', 'secreto123');

    await viewModel.signOut(force: true);

    expect(viewModel.state, isA<AuthSignedOut>());
    expect(repository.signOuts, [true]);
  });
}
