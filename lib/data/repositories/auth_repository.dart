import 'dart:async';
import 'dart:convert';

import '../../domain/models/app_user.dart';
import '../../domain/models/auth_failure.dart';
import '../../domain/models/user_role.dart';
import '../../utils/result.dart';
import '../local/app_database.dart';
import '../services/auth_service.dart';
import '../sync/sync_engine.dart';
import 'outbox_repository.dart';

abstract interface class AuthRepository {
  /// Signs in with email and password. Needs a connection: a person who never
  /// signed in on this device cannot sign in offline.
  ///
  /// The error is an [AuthFailureException].
  ///
  /// With [farmerOnly] (the DNI form) a profile that is not a farmer is
  /// rejected as invalid credentials and the session is dropped: a DNI-derived
  /// email can only belong to a farmer.
  Future<Result<AppUser>> signIn(
    String email,
    String password, {
    bool farmerOnly = false,
  });

  /// Emits when the server ends the session without the user asking (for
  /// example an expired refresh token while online). Never emits on an
  /// explicit sign-out, and never because the device is offline. The cached
  /// profile and the replica are kept so unsent records are not lost.
  Stream<void> get sessionExpired;

  /// The user of the session persisted on this device, or null when nobody is
  /// signed in. Works offline by falling back to the cached profile.
  Future<Result<AppUser?>> restore();

  /// Ends the session and wipes the local replica.
  ///
  /// Fails with [PendingDataBlocksSignOut] while records were never uploaded,
  /// unless [force] is true (their data is then discarded).
  Future<Result<void>> signOut({bool force = false});
}

/// Remembers the last signed-in user so the app can start offline.
abstract interface class SessionCache {
  Future<AppUser?> read();

  Future<void> write(AppUser user);

  Future<void> clear();
}

/// [SessionCache] kept in the `app_settings` table under `session_user`.
class DriftSessionCache implements SessionCache {
  DriftSessionCache(this._database);

  static const key = 'session_user';

  final AppDatabase _database;

  @override
  Future<AppUser?> read() async {
    final row = await (_database.select(
      _database.appSettings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    try {
      return AppUser.tryFromJson(jsonDecode(row.value));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(AppUser user) {
    return _database
        .into(_database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: jsonEncode(user.toJson()),
          ),
        );
  }

  @override
  Future<void> clear() {
    return (_database.delete(
      _database.appSettings,
    )..where((s) => s.key.equals(key))).go();
  }
}

/// Supabase-backed authentication with an offline-capable session restore.
///
/// Replica isolation rule: the local replica is wiped (via
/// [SyncEngine.resetForNewUser]) in two cases only:
///  * on sign-out, after the unsent-records guard has passed (or `force`);
///  * when a user signs in or is restored and the cached user is a DIFFERENT
///    person (e.g. the session expired without an explicit sign-out). Records
///    that person never uploaded are discarded then.
/// A plain sign-out therefore never silently deletes unsent records, and one
/// user's data is never visible to another.
class DefaultAuthRepository implements AuthRepository {
  DefaultAuthRepository({
    required AuthService service,
    required SessionCache cache,
    required OutboxRepository outbox,
    required SyncEngine syncEngine,
    this.networkTimeout = const Duration(seconds: 10),
  }) : _service = service,
       _cache = cache,
       _outbox = outbox,
       _syncEngine = syncEngine;

  final AuthService _service;
  final SessionCache _cache;
  final OutboxRepository _outbox;
  final SyncEngine _syncEngine;

  /// Upper bound for the network part of sign-in/restore, so an unreachable
  /// server counts as offline instead of hanging the splash screen.
  final Duration networkTimeout;

  @override
  Stream<void> get sessionExpired => _service.sessionEnded;

  @override
  Future<Result<AppUser>> signIn(
    String email,
    String password, {
    bool farmerOnly = false,
  }) async {
    try {
      final user = await _signInAndLoad(email.trim(), password);
      if (farmerOnly && user.role != UserRole.farmer) {
        await _quietSignOut();
        throw const AuthFailureException(AuthFailure.invalidCredentials);
      }
      await _adopt(user);
      return Result.ok(user);
    } on Object catch (error) {
      return Result.error(_asFailure(error));
    }
  }

  Future<AppUser> _signInAndLoad(String email, String password) async {
    final userId = await _service
        .signInWithPassword(email: email, password: password)
        .timeout(networkTimeout);
    try {
      return await _load(userId, fallbackEmail: email);
    } on Object {
      // Do not leave a half-usable session behind.
      await _quietSignOut();
      rethrow;
    }
  }

  @override
  Future<Result<AppUser?>> restore() async {
    final userId = _service.restoredUserId();
    if (userId == null) return const Result.ok(null);
    try {
      final user = await _load(userId);
      await _adopt(user);
      return Result.ok(user);
    } on Object catch (error) {
      final failure = _asFailure(error);
      switch (failure.failure) {
        case AuthFailure.offline || AuthFailure.unknown:
          final cached = await _cache.read();
          if (cached != null && cached.id == userId && cached.isActive) {
            return Result.ok(cached);
          }
          return Result.error(failure);
        case AuthFailure.inactiveAccount ||
            AuthFailure.noProfile ||
            AuthFailure.invalidCredentials ||
            AuthFailure.sessionExpired:
          await _quietSignOut();
          await _cache.clear();
          return Result.error(failure);
      }
    }
  }

  @override
  Future<Result<void>> signOut({bool force = false}) async {
    try {
      final summary = await _outbox.summary();
      final unsent = summary.pending + summary.error;
      if (unsent > 0 && !force) {
        return Result.error(PendingDataBlocksSignOut(unsent));
      }
      await _service.signOut();
      await _cache.clear();
      await _syncEngine.resetForNewUser();
      return const Result.ok(null);
    } on Object catch (error) {
      return Result.error(_asFailure(error));
    }
  }

  Future<AppUser> _load(String userId, {String fallbackEmail = ''}) async {
    final profile = await _service.fetchProfile(userId).timeout(networkTimeout);
    if (profile == null) {
      throw const AuthFailureException(AuthFailure.noProfile);
    }

    final base = AppUser.fromProfile(profile, fallbackEmail: fallbackEmail);
    if (base == null) throw const AuthFailureException(AuthFailure.noProfile);
    if (!base.isActive) {
      throw const AuthFailureException(AuthFailure.inactiveAccount);
    }

    if (base.role == UserRole.farmer) {
      final farmerId = await _service
          .fetchFarmerId(userId)
          .timeout(networkTimeout);
      // A farmer without a farmers row has no data to work with.
      if (farmerId == null) {
        throw const AuthFailureException(AuthFailure.noProfile);
      }
      return AppUser.fromProfile(
        profile,
        farmerId: farmerId,
        fallbackEmail: fallbackEmail,
      )!;
    }
    final zoneIds = await _service.fetchZoneIds(userId).timeout(networkTimeout);
    return AppUser.fromProfile(
      profile,
      zoneIds: zoneIds,
      fallbackEmail: fallbackEmail,
    )!;
  }

  /// Caches [user]; wipes the replica first when the cache held someone else.
  Future<void> _adopt(AppUser user) async {
    final previous = await _cache.read();
    if (previous != null && previous.id != user.id) {
      await _syncEngine.resetForNewUser();
    }
    await _cache.write(user);
  }

  Future<void> _quietSignOut() async {
    try {
      await _service.signOut();
    } on Object {
      // Best effort: the caller is already reporting the original failure.
    }
  }

  AuthFailureException _asFailure(Object error) {
    if (error is AuthFailureException) return error;
    if (error is TimeoutException) {
      return AuthFailureException(AuthFailure.offline, error);
    }
    return AuthFailureException(AuthFailure.unknown, error);
  }
}
