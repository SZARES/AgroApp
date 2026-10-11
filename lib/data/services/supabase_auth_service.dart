import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/auth_failure.dart';
import 'auth_service.dart';

/// Supabase Auth + the profile lookups needed right after signing in.
class SupabaseAuthService implements AuthService {
  const SupabaseAuthService(this._client);

  final SupabaseClient _client;

  @override
  Future<String> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailureException(AuthFailure.unknown);
      }
      return user.id;
    } on AuthFailureException {
      rethrow;
    } catch (error) {
      throw _classify(error, authErrorsAreCredentials: true);
    }
  }

  @override
  String? restoredUserId() =>
      (_client.auth.currentSession?.user ?? _client.auth.currentUser)?.id;

  @override
  Future<void> signOut() => _client.auth.signOut(scope: SignOutScope.local);

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) => _guard(() async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  });

  @override
  Future<String?> fetchFarmerId(String userId) => _guard(() async {
    final row = await _client
        .from('farmers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['id'] as String?;
  });

  @override
  Future<List<String>> fetchZoneIds(String userId) => _guard(() async {
    final rows = await _client
        .from('user_zones')
        .select('zone_id')
        .eq('user_id', userId);
    return [for (final row in rows) row['zone_id'] as String];
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw _classify(error);
    }
  }

  AuthFailureException _classify(
    Object error, {
    bool authErrorsAreCredentials = false,
  }) {
    if (error is AuthFailureException) return error;
    if (error is AuthRetryableFetchException) {
      return AuthFailureException(AuthFailure.offline, error);
    }
    if (error is AuthException) {
      final isCredentials =
          authErrorsAreCredentials &&
          (error.code == 'invalid_credentials' ||
              error.statusCode == '400' ||
              error.statusCode == '401');
      return AuthFailureException(
        isCredentials ? AuthFailure.invalidCredentials : AuthFailure.unknown,
        error,
      );
    }
    if (error is PostgrestException) {
      return AuthFailureException(AuthFailure.unknown, error);
    }
    // Socket, HTTP client and timeout errors: the network is not reachable.
    return AuthFailureException(AuthFailure.offline, error);
  }
}
