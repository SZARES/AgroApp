import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/auth_repository.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/data/sync/sync_engine.dart';
import 'package:hackathon/domain/models/app_user.dart';
import 'package:hackathon/domain/models/auth_failure.dart';
import 'package:hackathon/domain/models/sync_op.dart';
import 'package:hackathon/domain/models/user_role.dart';
import 'package:hackathon/utils/result.dart';

import '../../testing/fakes.dart';

void main() {
  late AppDatabase database;
  late OutboxRepository outbox;
  late LocalStore store;
  late FakeAuthService service;
  late DriftSessionCache cache;
  late SyncEngine engine;
  late DefaultAuthRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    outbox = OutboxRepository(database);
    store = LocalStore(database, outbox);
    service = FakeAuthService();
    cache = DriftSessionCache(database);
    engine = SyncEngine(
      repository: outbox,
      localStore: store,
      syncService: FakeSyncService(),
      connectivity: FakeConnectivityService(),
    );
    repository = DefaultAuthRepository(
      service: service,
      cache: cache,
      outbox: outbox,
      syncEngine: engine,
      networkTimeout: const Duration(milliseconds: 200),
    );
  });

  tearDown(() async {
    await engine.dispose();
    await database.close();
  });

  AuthFailure? failureOf<T>(Result<T> result) => switch (result) {
    Error(:final error) when error is AuthFailureException => error.failure,
    _ => null,
  };

  T valueOf<T>(Result<T> result) => (result as Ok<T>).value;

  group('signIn', () {
    test('a farmer gets the farmer id and no zones', () async {
      final user = valueOf(
        await repository.signIn('ana@correo.pe', 'secreto123'),
      );

      expect(user.role, UserRole.farmer);
      expect(user.farmerId, 'f1');
      expect(user.zoneIds, isEmpty);
      expect(user.fullName, 'Ana Quispe');
    });

    for (final role in ['technician', 'supervisor', 'admin']) {
      test('$role gets its zones and no farmer id', () async {
        service.profile = profileRow(role: role);
        service.zoneIds = ['z1', 'z2'];

        final user = valueOf(await repository.signIn('a@b.pe', 'secreto123'));

        expect(user.role.name, role);
        expect(user.farmerId, isNull);
        expect(user.zoneIds, ['z1', 'z2']);
      });
    }

    test('maps wrong credentials', () async {
      final result = await repository.signIn('ana@correo.pe', 'incorrecta');

      expect(failureOf(result), AuthFailure.invalidCredentials);
      expect(await cache.read(), isNull);
    });

    test('rejects an inactive account and drops the session', () async {
      service.profile = profileRow(status: 'inactive');

      final result = await repository.signIn('ana@correo.pe', 'secreto123');

      expect(failureOf(result), AuthFailure.inactiveAccount);
      expect(service.sessionUserId, isNull);
      expect(await cache.read(), isNull);
    });

    test('rejects a suspended account', () async {
      service.profile = profileRow(status: 'suspended');

      final result = await repository.signIn('ana@correo.pe', 'secreto123');

      expect(failureOf(result), AuthFailure.inactiveAccount);
    });

    test('reports a missing profile', () async {
      service.profile = null;

      final result = await repository.signIn('ana@correo.pe', 'secreto123');

      expect(failureOf(result), AuthFailure.noProfile);
      expect(service.sessionUserId, isNull);
    });

    test('a farmer without a farmers row has no profile either', () async {
      service.farmerId = null;

      final result = await repository.signIn('ana@correo.pe', 'secreto123');

      expect(failureOf(result), AuthFailure.noProfile);
    });

    test('offline sign-in is reported as offline', () async {
      service.signInError = const AuthFailureException(AuthFailure.offline);

      final result = await repository.signIn('ana@correo.pe', 'secreto123');

      expect(failureOf(result), AuthFailure.offline);
    });

    test('a hanging network counts as offline', () async {
      service.signInError = null;
      final slow = DefaultAuthRepository(
        service: _HangingService(),
        cache: cache,
        outbox: outbox,
        syncEngine: engine,
        networkTimeout: const Duration(milliseconds: 20),
      );

      expect(failureOf(await slow.signIn('a@b.pe', 'x')), AuthFailure.offline);
    });

    test('caches the user for offline restores', () async {
      final user = valueOf(
        await repository.signIn('ana@correo.pe', 'secreto123'),
      );

      expect(await cache.read(), user);
    });

    test('keeps the replica for the same user', () async {
      await repository.signIn('ana@correo.pe', 'secreto123');
      await store.applyServerRows('zones', [
        {'id': 'z1', 'updated_at': '2026-01-01T00:00:00Z'},
      ]);

      await repository.signIn('ana@correo.pe', 'secreto123');

      expect(await store.list('zones'), hasLength(1));
    });

    test('wipes the replica when a different user signs in', () async {
      await repository.signIn('ana@correo.pe', 'secreto123');
      await store.applyServerRows('zones', [
        {'id': 'z1', 'updated_at': '2026-01-01T00:00:00Z'},
      ]);
      service
        ..userId = 'u2'
        ..profile = profileRow(id: 'u2', role: 'technician');

      await repository.signIn('otro@correo.pe', 'secreto123');

      expect(await store.list('zones'), isEmpty);
      expect((await cache.read())?.id, 'u2');
    });
  });

  group('restore', () {
    test('returns null when no session is persisted', () async {
      expect(valueOf(await repository.restore()), isNull);
    });

    test('refreshes the profile when online', () async {
      service.sessionUserId = 'u1';

      final user = valueOf(await repository.restore());

      expect(user?.role, UserRole.farmer);
      expect(await cache.read(), user);
    });

    test('works offline from the cached profile', () async {
      final signedIn = valueOf(
        await repository.signIn('ana@correo.pe', 'secreto123'),
      );
      service.fetchError = const AuthFailureException(AuthFailure.offline);

      final restored = valueOf(await repository.restore());

      expect(restored, signedIn);
    });

    test('offline without a cache fails as offline', () async {
      service
        ..sessionUserId = 'u1'
        ..fetchError = const AuthFailureException(AuthFailure.offline);

      expect(failureOf(await repository.restore()), AuthFailure.offline);
    });

    test('does not use another user\'s cache', () async {
      await repository.signIn('ana@correo.pe', 'secreto123');
      service
        ..sessionUserId = 'u2'
        ..fetchError = const AuthFailureException(AuthFailure.offline);

      expect(failureOf(await repository.restore()), AuthFailure.offline);
    });

    test('a deactivated account is signed out and uncached', () async {
      await repository.signIn('ana@correo.pe', 'secreto123');
      service.profile = profileRow(status: 'inactive');

      final result = await repository.restore();

      expect(failureOf(result), AuthFailure.inactiveAccount);
      expect(service.sessionUserId, isNull);
      expect(await cache.read(), isNull);
    });
  });

  group('signOut', () {
    Future<void> queueUnsentRecord() => store.save(
      table: 'activities',
      id: 'a1',
      row: {'quantity': 1},
      op: SyncOp.batch,
    );

    test('clears the session, the cache and the replica', () async {
      await repository.signIn('ana@correo.pe', 'secreto123');
      await store.applyServerRows('zones', [
        {'id': 'z1', 'updated_at': '2026-01-01T00:00:00Z'},
      ]);

      final result = await repository.signOut();

      expect(result, isA<Ok<void>>());
      expect(service.sessionUserId, isNull);
      expect(await cache.read(), isNull);
      expect(await store.list('zones'), isEmpty);
    });

    test('is blocked while records were never uploaded', () async {
      await repository.signIn('ana@correo.pe', 'secreto123');
      await queueUnsentRecord();

      final result = await repository.signOut();

      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, isA<PendingDataBlocksSignOut>());
      expect((result.error as PendingDataBlocksSignOut).unsentCount, 1);
      expect(service.sessionUserId, 'u1');
      expect(await cache.read(), isNotNull);
      expect(await store.get('activities', 'a1'), isNotNull);
    });

    test('force discards the unsent records', () async {
      await repository.signIn('ana@correo.pe', 'secreto123');
      await queueUnsentRecord();

      final result = await repository.signOut(force: true);

      expect(result, isA<Ok<void>>());
      expect(service.sessionUserId, isNull);
      expect(await store.get('activities', 'a1'), isNull);
      expect((await outbox.summary()).pending, 0);
    });
  });

  group('AppUser', () {
    test('round-trips through json', () {
      const user = AppUser(
        id: 'u1',
        email: 'a@b.pe',
        fullName: 'Ana',
        role: UserRole.technician,
        status: UserStatus.active,
        zoneIds: ['z1'],
      );

      expect(AppUser.tryFromJson(user.toJson()), user);
    });

    test('rejects an unknown role', () {
      expect(AppUser.tryFromJson({'id': 'u1', 'role': 'ceo'}), isNull);
    });
  });
}

class _HangingService extends FakeAuthService {
  @override
  Future<String> signInWithPassword({
    required String email,
    required String password,
  }) => Completer<String>().future;
}
