import 'package:flutter/foundation.dart';

import '../../../../domain/models/app_user.dart';
import '../../../../domain/models/auth_failure.dart';
import '../../../../domain/models/login_identifier.dart';
import '../../../../utils/result.dart';
import '../../auth/view_models/auth_view_model.dart';

enum LoginError {
  invalidEmail,
  invalidDni,
  missingPassword,
  invalidCredentials,
  inactiveAccount,
  noProfile,
  offline,
  unknown,
}

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthViewModel authViewModel})
    : _authViewModel = authViewModel;

  final AuthViewModel _authViewModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  LoginError? _error;
  LoginError? get error => _error;

  bool _isDisposed = false;

  /// Returns the signed-in user, or null when [error] explains the failure.
  ///
  /// [identifier] is what the person typed: a farmer's DNI or an email.
  Future<AppUser?> signIn(String identifier, String password) async {
    if (_isLoading) return null;
    final parsed = LoginIdentifier.parse(identifier);
    final login = parsed.identifier;
    if (login == null) {
      return _fail(switch (parsed.error!) {
        LoginIdentifierError.invalidDni => LoginError.invalidDni,
        LoginIdentifierError.invalidIdentifier => LoginError.invalidEmail,
      });
    }
    // Length rules apply when a password is created, not when it is used.
    if (password.isEmpty) return _fail(LoginError.missingPassword);

    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authViewModel.signIn(
      login.authEmail,
      password,
      farmerOnly: login.isDni,
    );
    _isLoading = false;
    _wasDni = login.isDni;
    switch (result) {
      case Ok(:final value):
        _notify();
        return value;
      case Error(:final error):
        return _fail(_errorFor(error));
    }
  }

  /// Whether the last attempt used the DNI form (picks the wording of
  /// [LoginError.invalidCredentials]).
  bool get lastWasDni => _wasDni;
  bool _wasDni = false;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  LoginError _errorFor(Exception error) {
    if (error is! AuthFailureException) return LoginError.unknown;
    return switch (error.failure) {
      AuthFailure.invalidCredentials => LoginError.invalidCredentials,
      AuthFailure.inactiveAccount => LoginError.inactiveAccount,
      AuthFailure.noProfile => LoginError.noProfile,
      AuthFailure.offline => LoginError.offline,
      AuthFailure.sessionExpired => LoginError.unknown,
      AuthFailure.unknown => LoginError.unknown,
    };
  }

  AppUser? _fail(LoginError error) {
    _error = error;
    _notify();
    return null;
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
