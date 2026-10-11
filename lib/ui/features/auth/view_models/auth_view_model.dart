import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../domain/models/app_user.dart';
import '../../../../domain/models/auth_failure.dart';
import '../../../../utils/result.dart';

sealed class AuthState {
  const AuthState();
}

/// Startup: the persisted session has not been checked yet.
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);

  final AppUser user;
}

/// App-wide session state: who is signed in, if anyone.
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required AuthRepository authRepository,
    required Future<Object?> Function() requestSync,
  }) : _authRepository = authRepository,
       _requestSync = requestSync;

  final AuthRepository _authRepository;

  /// Starts an immediate sync with a forced pull (`SyncEngine.syncNow`), so
  /// the profile and catalogs arrive right after signing in.
  final Future<Object?> Function() _requestSync;

  AuthState _state = const AuthUnknown();
  AuthState get state => _state;

  /// The signed-in user, or null.
  AppUser? get user => switch (_state) {
    AuthSignedIn(:final user) => user,
    _ => null,
  };

  /// Why the persisted session could not be restored at startup, if it could
  /// not (for example an account that was deactivated).
  AuthFailure? get restoreFailure => _restoreFailure;
  AuthFailure? _restoreFailure;

  /// Checks the persisted session; works offline from the cached profile.
  Future<void> bootstrap() async {
    final result = await _authRepository.restore();
    switch (result) {
      case Ok(:final value):
        if (value == null) {
          _setSignedOut();
        } else {
          _setSignedIn(value);
        }
      case Error(:final error):
        _restoreFailure = error is AuthFailureException ? error.failure : null;
        _setSignedOut();
    }
  }

  Future<Result<AppUser>> signIn(String email, String password) async {
    final result = await _authRepository.signIn(email, password);
    if (result case Ok(:final value)) {
      _restoreFailure = null;
      _setSignedIn(value);
    }
    return result;
  }

  /// Fails with `PendingDataBlocksSignOut` while unsent records exist, unless
  /// [force] is true.
  Future<Result<void>> signOut({bool force = false}) async {
    final result = await _authRepository.signOut(force: force);
    if (result is Ok<void>) _setSignedOut();
    return result;
  }

  void _setSignedIn(AppUser user) {
    _state = AuthSignedIn(user);
    // Pull catalogs and the profile right away instead of waiting for a tick.
    unawaited(_requestSync());
    notifyListeners();
  }

  void _setSignedOut() {
    _state = const AuthSignedOut();
    notifyListeners();
  }
}
