import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/admin_repository.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/data/services/admin_service.dart';
import 'package:hackathon/domain/models/admin/admin_failure.dart';
import 'package:hackathon/domain/models/admin/catalog_defs.dart';
import 'package:hackathon/domain/models/admin/create_user_request.dart';
import 'package:hackathon/domain/models/app_user.dart';
import 'package:hackathon/domain/models/user_role.dart';
import 'package:hackathon/utils/result.dart';

import '../../testing/admin_fakes.dart';
import '../../testing/fakes.dart';

AdminFailure _failure(Result<Object?> result) {
  expect(result, isA<Error<Object?>>());
  return ((result as Error<Object?>).error as AdminFailureException).failure;
}

void main() {
  late AppDatabase database;
  late LocalStore store;
  late FakeAdminService service;
  late FakeConnectivityService connectivity;
  late DefaultAdminRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = LocalStore(database, OutboxRepository(database));
    service = FakeAdminService();
    connectivity = FakeConnectivityService();
    repository = DefaultAdminRepository(
      service: service,
      store: store,
      connectivity: connectivity,
      clock: () => DateTime.utc(2026, 5, 1, 12),
    );
  });

  tearDown(() => database.close());

  group('createUser', () {
    test('farmer body carries dni and no email', () async {
      final result = await repository.createUser(
        const CreateUserRequest(
          role: UserRole.farmer,
          fullName: 'Ana Quispe',
          password: 'abcdefgh',
          dni: '71226316',
        ),
      );

      final created = (result as Ok<CreatedUser>).value;
      expect(created.loginHint, 'Entra con su DNI 71226316');
      final body = service.createdBodies.single;
      expect(body['dni'], '71226316');
      expect(body.containsKey('email'), isFalse);
    });

    test('staff body carries email and no dni', () async {
      final result = await repository.createUser(
        const CreateUserRequest(
          role: UserRole.supervisor,
          fullName: 'Luis Rojas',
          password: 'abcdefgh',
          email: 'luis@aider.pe',
          zoneIds: ['z1'],
        ),
      );

      final created = (result as Ok<CreatedUser>).value;
      expect(created.loginHint, 'Entra con su correo luis@aider.pe');
      final body = service.createdBodies.single;
      expect(body['email'], 'luis@aider.pe');
      expect(body['zone_ids'], ['z1']);
      expect(body.containsKey('dni'), isFalse);
    });

    test('maps server errors', () async {
      const request = CreateUserRequest(
        role: UserRole.farmer,
        fullName: 'Ana Quispe',
        password: 'abcdefgh',
        dni: '71226316',
      );

      service.failWith = const AdminServiceException(
        statusCode: 400,
        message: 'Ese DNI ya existe',
      );
      var result = await repository.createUser(request);
      expect(_failure(result), AdminFailure.invalid);
      expect(
        ((result as Error).error as AdminFailureException).message,
        'Ese DNI ya existe',
      );

      service.failWith = const AdminServiceException(statusCode: 403);
      expect(
        _failure(await repository.createUser(request)),
        AdminFailure.forbidden,
      );

      service.failWith = const AdminServiceException(statusCode: 401);
      expect(
        _failure(await repository.createUser(request)),
        AdminFailure.forbidden,
      );

      service.failWith = const AdminServiceException(isNetwork: true);
      result = await repository.createUser(request);
      expect(_failure(result), AdminFailure.offline);
    });
  });

  test('offline blocks every write with the friendly message', () async {
    connectivity.online = false;

    final result = await repository.setUserStatus('u1', UserStatus.inactive);

    expect(_failure(result), AdminFailure.offline);
    expect(
      ((result as Error).error as AdminFailureException).message,
      'Necesita conexión a internet para guardar cambios de administración.',
    );
    expect(service.manageBodies, isEmpty);
  });

  group('catalogs', () {
    test('insert generates an id and updates the replica', () async {
      final result = await repository.saveCatalogRow(CatalogDefs.zones, {
        'code': 'PIU',
        'name': 'Piura',
      });

      final stored = (result as Ok<Map<String, dynamic>>).value;
      final id = stored['id'] as String;
      expect(id, isNotEmpty);
      expect(service.inserts.single.table, 'zones');
      expect((await store.get('zones', id))!['name'], 'Piura');
    });

    test('a known id is an update without the id in the body', () async {
      await store.applyServerRows('zones', [
        {
          'id': 'z1',
          'code': 'PIU',
          'name': 'Piura',
          'updated_at': '2026-01-01T00:00:00Z',
        },
      ]);

      await repository.saveCatalogRow(CatalogDefs.zones, {
        'id': 'z1',
        'name': 'Piura Norte',
      });

      final update = service.updates.single;
      expect(update.id, 'z1');
      expect(update.changes.containsKey('id'), isFalse);
      expect((await store.get('zones', 'z1'))!['name'], 'Piura Norte');
    });

    test('duplicate code is reported in Spanish', () async {
      service.failWith = const AdminServiceException(code: '23505');

      final result = await repository.saveCatalogRow(CatalogDefs.zones, {
        'code': 'PIU',
        'name': 'Piura',
      });

      expect(_failure(result), AdminFailure.duplicate);
      expect(
        ((result as Error).error as AdminFailureException).message,
        'Ya existe un registro con ese código.',
      );
    });

    test('settings upsert on the key', () async {
      await repository.saveSetting('sync.interval', {'seconds': 5});

      expect(service.upserts.single.onConflict, 'key');
      expect((await store.get('app_settings', 'sync.interval'))!['value'], {
        'seconds': 5,
      });
    });

    test('validating an equivalence stamps validator and time', () async {
      await repository.saveCatalogRow(CatalogDefs.unitEquivalences, {
        'unit_id': 'u1',
        'kg_per_unit': 50,
        'validated': true,
      });

      final row = service.inserts.single.row;
      expect(row['validated_by'], 'admin-1');
      expect(row['validated_at'], '2026-05-01T12:00:00.000Z');
    });

    test(
      'un-validating clears the stamp; already validated keeps it',
      () async {
        await store.applyServerRows('unit_equivalences', [
          {
            'id': 'e1',
            'unit_id': 'u1',
            'kg_per_unit': 50,
            'validated': true,
            'validated_by': 'other',
            'validated_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
          },
        ]);

        await repository.saveCatalogRow(CatalogDefs.unitEquivalences, {
          'id': 'e1',
          'validated': true,
          'kg_per_unit': 51,
        });
        expect(
          service.updates.last.changes.containsKey('validated_by'),
          isFalse,
        );

        await repository.saveCatalogRow(CatalogDefs.unitEquivalences, {
          'id': 'e1',
          'validated': false,
          'kg_per_unit': 51,
        });
        expect(service.updates.last.changes['validated_by'], isNull);
        expect(service.updates.last.changes['validated_at'], isNull);
      },
    );

    test(
      'setActive false deactivates; tables without active use deleted_at',
      () async {
        await repository.setActive(CatalogDefs.crops, 'c1', false);
        expect(service.updates.last.changes, {'active': false});

        await repository.setActive(CatalogDefs.unitEquivalences, 'e1', false);
        expect(
          service.updates.last.changes['deleted_at'],
          '2026-05-01T12:00:00.000Z',
        );
      },
    );
  });

  group('join tables replace the set', () {
    test('deletes the missing and inserts the new', () async {
      await store.applyServerRows('user_zones', [
        {'user_id': 'u1', 'zone_id': 'z1'},
        {'user_id': 'u1', 'zone_id': 'z2'},
        {'user_id': 'other', 'zone_id': 'z9'},
      ], idOf: (row) => '${row['user_id']}|${row['zone_id']}');

      final result = await repository.setUserZones('u1', ['z2', 'z3']);

      expect(result, isA<Ok<void>>());
      expect(service.joinDeletes.single.match, {
        'user_id': 'u1',
        'zone_id': 'z1',
      });
      expect(service.joinInserts.single.rows, [
        {'user_id': 'u1', 'zone_id': 'z3'},
      ]);
      final zones = await store.list(
        'user_zones',
        where: (row) => row['user_id'] == 'u1',
      );
      expect(zones.map((r) => r['zone_id']).toSet(), {'z2', 'z3'});
      expect(
        (await store.list(
          'user_zones',
          where: (r) => r['user_id'] == 'other',
        )).length,
        1,
      );
    });

    test('allowed units use the join definition', () async {
      await repository.setAllowedUnits(
        CatalogDefs.crops.allowedUnits!,
        'crop1',
        ['u1'],
      );

      expect(service.joinInserts.single.table, 'crop_harvest_units');
      expect(service.joinInserts.single.rows, [
        {'crop_id': 'crop1', 'unit_id': 'u1'},
      ]);
    });
  });

  group('users', () {
    test(
      'status change calls the Edge Function and updates the replica',
      () async {
        await store.applyServerRows('profiles', [
          {
            'id': 'u1',
            'full_name': 'Ana',
            'role': 'farmer',
            'status': 'active',
            'updated_at': '2026-01-01T00:00:00Z',
          },
        ]);

        await repository.setUserStatus('u1', UserStatus.suspended);

        expect(service.manageBodies.single, {
          'user_id': 'u1',
          'action': 'set_status',
          'status': 'suspended',
        });
        expect((await store.get('profiles', 'u1'))!['status'], 'suspended');
      },
    );

    test('reset password sends the new password', () async {
      await repository.resetPassword('u1', 'nuevaClave1');

      expect(service.manageBodies.single['action'], 'reset_password');
      expect(service.manageBodies.single['password'], 'nuevaClave1');
    });

    test('watchUsers joins profile, farmer, community and zones', () async {
      await store.applyServerRows('profiles', [
        {
          'id': 'u1',
          'full_name': 'Ana Quispe',
          'email': '71226316@agricultores.agroapp',
          'role': 'farmer',
          'status': 'active',
          'updated_at': '2026-01-01T00:00:00Z',
        },
        {
          'id': 'u2',
          'full_name': 'Luis Rojas',
          'email': 'luis@aider.pe',
          'role': 'technician',
          'status': 'inactive',
          'updated_at': '2026-01-01T00:00:00Z',
        },
      ]);
      await store.applyServerRows('farmers', [
        {
          'id': 'f1',
          'user_id': 'u1',
          'dni': '71226316',
          'community_id': 'c1',
          'updated_at': '2026-01-01T00:00:00Z',
        },
      ]);
      await store.applyServerRows('communities', [
        {
          'id': 'c1',
          'zone_id': 'z1',
          'name': 'Chulucanas',
          'updated_at': '2026-01-01T00:00:00Z',
        },
      ]);
      await store.applyServerRows('zones', [
        {'id': 'z1', 'name': 'Piura', 'updated_at': '2026-01-01T00:00:00Z'},
      ]);
      await store.applyServerRows('user_zones', [
        {'user_id': 'u2', 'zone_id': 'z1'},
      ], idOf: (row) => '${row['user_id']}|${row['zone_id']}');

      final users = await repository.watchUsers().firstWhere(
        (list) => list.length == 2,
      );

      expect(users.first.fullName, 'Ana Quispe');
      expect(users.first.dni, '71226316');
      expect(users.first.communityName, 'Chulucanas');
      expect(users.first.subtitle, 'DNI 71226316 · Chulucanas');
      expect(users.last.zoneNames, ['Piura']);
    });
  });

  test('audit logs are fetched through the service', () async {
    service.auditRows = [
      {
        'id': 'a1',
        'action': 'INSERT',
        'table_name': 'zones',
        'record_id': 'z1',
        'created_at': '2026-05-01T10:00:00Z',
      },
      {'id': 'broken', 'created_at': 'not a date'},
    ];

    final result = await repository.fetchAuditLogs();

    expect((result as Ok).value.length, 1);
  });
}
