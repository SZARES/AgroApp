import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../domain/models/app_user.dart';
import '../../../../utils/result.dart';

enum LoginError { invalidFormat, unknownDni }

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthRepository authRepository})
    : _authRepository = authRepository;

  static const dniLength = 8;
  static final _dniPattern = RegExp(r'^\d{8}$');

  final AuthRepository _authRepository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  LoginError? _error;
  LoginError? get error => _error;

  /// Returns the signed-in user, or null when [error] explains the failure.
  Future<AppUser?> signIn(String dni) async {
    final normalized = dni.trim();
    if (!_dniPattern.hasMatch(normalized)) {
      _error = LoginError.invalidFormat;
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authRepository.signInWithDni(normalized);
    _isLoading = false;
    switch (result) {
      case Ok(:final value):
        notifyListeners();
        return value;
      case Error():
        _error = LoginError.unknownDni;
        notifyListeners();
        return null;
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
