import '../../domain/models/app_user.dart';
import '../../domain/models/user_role.dart';
import '../../utils/result.dart';

class UnknownDniException implements Exception {
  const UnknownDniException(this.dni);

  final String dni;

  @override
  String toString() => 'UnknownDniException($dni)';
}

abstract interface class AuthRepository {
  Future<Result<AppUser>> signInWithDni(String dni);
}

/// Static users for the mockup; replace with Supabase Auth when login is real.
class MockAuthRepository implements AuthRepository {
  const MockAuthRepository();

  static const _rolesByDni = {
    '71226316': UserRole.farmer,
    '75582477': UserRole.technician,
    '75501107': UserRole.supervisor,
    '71226320': UserRole.admin,
  };

  @override
  Future<Result<AppUser>> signInWithDni(String dni) async {
    final normalized = dni.trim();
    final role = _rolesByDni[normalized];
    if (role == null) return Result.error(UnknownDniException(normalized));
    return Result.ok(AppUser(dni: normalized, role: role));
  }
}
