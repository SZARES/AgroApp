import 'package:flutter/foundation.dart';

import '../../../../domain/models/app_user.dart';
import '../../../../domain/models/auth_failure.dart';
import '../../../../utils/result.dart';
import '../../auth/view_models/auth_view_model.dart';

enum LoginError {
  invalidEmail,
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

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final AuthViewModel _authViewModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  LoginError? _error;
  LoginError? get error => _error;

  bool _isDisposed = false;

  /// Returns the signed-in user, or null when [error] explains the failure.
  Future<AppUser?> signIn(String email, String password) async {
    if (_isLoading) return null;
    if (!_emailPattern.hasMatch(email.trim())) {
      return _fail(LoginError.invalidEmail);
    }
    // Length rules apply when a password is created, not when it is used.
    if (password.isEmpty) return _fail(LoginError.missingPassword);

    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authViewModel.signIn(email, password);
    _isLoading = false;
    switch (result) {
      case Ok(:final value):
        _notify();
        return value;
      case Error(:final error):
        return _fail(_errorFor(error));
    }
  }

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
