import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/domain/models/admin/admin_failure.dart';
import 'package:hackathon/domain/models/admin/admin_user.dart';
import 'package:hackathon/domain/models/admin/catalog_defs.dart';
import 'package:hackathon/domain/models/admin/create_user_request.dart';
import 'package:hackathon/domain/models/admin/password_generator.dart';
import 'package:hackathon/domain/models/app_user.dart';
import 'package:hackathon/domain/models/user_role.dart';
import 'package:hackathon/ui/features/admin/view_models/catalog_view_model.dart';
import 'package:hackathon/ui/features/admin/view_models/create_user_view_model.dart';
import 'package:hackathon/ui/features/admin/view_models/users_view_model.dart';
import 'package:hackathon/utils/result.dart';

import '../../../testing/admin_fakes.dart';

AdminUser _user(
  String id,
  String name, {
  UserRole role = UserRole.farmer,
  UserStatus status = UserStatus.active,
  String? dni,
  String email = '',
  List<String> zoneIds = const [],
}) => AdminUser(
  id: id,
  fullName: name,
  email: email,
  role: role,
  status: status,
  dni: dni,
  zoneIds: zoneIds,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAdminRepository repository;

  setUp(() => repository = FakeAdminRepository());

  group('AdminUsersViewModel', () {
    test('loads, then filters by role, status and search', () async {
      final vm = AdminUsersViewModel(repository: repository);
      expect(vm.loading, isTrue);

      repository.usersController.add([
        _user('1', 'Ana Quispe', dni: '71226316', email: 'ana@x.pe'),
        _user(
          '2',
          'Luis Rojas',
          role: UserRole.technician,
          email: 'luis@aider.pe',
        ),
        _user(
          '3',
          'Marta Paz',
          role: UserRole.technician,
          status: UserStatus.inactive,
          email: 'marta@aider.pe',
        ),
      ]);
      await _settle();
      expect(vm.loading, isFalse);
      expect(vm.visible.length, 3);

      vm.setRoleFilter(UserRole.technician);
      expect(vm.visible.map((u) => u.id), ['2', '3']);

      vm.setStatusFilter(UserStatus.inactive);
      expect(vm.visible.map((u) => u.id), ['3']);

      vm.setRoleFilter(null);
      vm.setStatusFilter(null);
      vm.setQuery('7122');
      expect(vm.visible.map((u) => u.id), ['1']);
      vm.setQuery('LUIS@aider');
      expect(vm.visible.map((u) => u.id), ['2']);
      vm.setQuery('rojas');
      expect(vm.visible.map((u) => u.id), ['2']);
      vm.dispose();
    });

    test('selecting a user leaves create mode', () async {
      final vm = AdminUsersViewModel(repository: repository);
      repository.usersController.add([_user('1', 'Ana')]);
      await _settle();

      vm.startCreate();
      expect(vm.creating, isTrue);
      vm.select('1');

      expect(vm.creating, isFalse);
      expect(vm.selected?.fullName, 'Ana');
      vm.dispose();
    });

    test('an admin cannot deactivate their own account', () async {
      final vm = AdminUsersViewModel(repository: repository);
      final me = _user('admin-1', 'Yo', role: UserRole.admin);

      final ok = await vm.setStatus(me, UserStatus.inactive);

      expect(ok, isFalse);
      expect(vm.messageIsError, isTrue);
      expect(repository.statusChanges, isEmpty);
      vm.dispose();
    });

    test('short passwords are rejected before calling the backend', () async {
      final vm = AdminUsersViewModel(repository: repository);
      final ok = await vm.resetPassword(_user('1', 'Ana'), 'corta');

      expect(ok, isFalse);
      expect(repository.passwordResets, isEmpty);

      expect(await vm.resetPassword(_user('1', 'Ana'), 'suficiente1'), isTrue);
      expect(repository.passwordResets.single.id, '1');
      expect(vm.message, 'Contraseña cambiada');
      vm.dispose();
    });

    test('assignable parcels follow the technician zones', () async {
      final vm = AdminUsersViewModel(repository: repository);
      repository.emitRows('parcels', [
        {'id': 'p1', 'zone_id': 'z1', 'name': 'A'},
        {'id': 'p2', 'zone_id': 'z2', 'name': 'B'},
      ]);
      repository.emitRows('technician_parcels', [
        {'technician_id': 't1', 'parcel_id': 'p1'},
      ]);
      await _settle();

      final tech = _user(
        't1',
        'Luis',
        role: UserRole.technician,
        zoneIds: ['z1'],
      );
      expect(vm.assignableParcels(tech).map((p) => p['id']), ['p1']);
      expect(vm.assignedParcelIds('t1'), {'p1'});
      vm.dispose();
    });
  });

  group('CreateUserViewModel', () {
    CreateUserViewModel build() => CreateUserViewModel(
      repository: repository,
      zones: const [
        {'id': 'z1', 'name': 'Piura'},
        {'id': 'z2', 'name': 'Sullana'},
      ],
      communities: const [
        {'id': 'c1', 'zone_id': 'z1', 'name': 'Chulucanas'},
        {'id': 'c2', 'zone_id': 'z2', 'name': 'Marcavelica'},
      ],
      random: Random(1),
    );

    test('nothing is submitted until a role is chosen', () async {
      final vm = build();

      expect(await vm.submit(), isFalse);
      expect(repository.createRequests, isEmpty);
    });

    test('farmer needs a DNI; staff needs an email', () async {
      final vm = build()
        ..setRole(UserRole.farmer)
        ..fullName = 'Ana Quispe'
        ..password = 'abcdefgh';

      expect(await vm.submit(), isFalse);
      expect(vm.errors.keys, [UserFormField.dni]);

      vm.dni = '71226316';
      expect(await vm.submit(), isTrue);
      expect(repository.createRequests.single.role, UserRole.farmer);

      final staff = build()
        ..setRole(UserRole.technician)
        ..fullName = 'Luis Rojas'
        ..password = 'abcdefgh';
      expect(await staff.submit(), isFalse);
      expect(staff.errors.keys, [UserFormField.email]);
    });

    test('changing the role resets role-specific fields', () {
      final vm = build()
        ..setRole(UserRole.technician)
        ..toggleZone('z1', true)
        ..setRole(UserRole.farmer);

      expect(vm.zoneIds, isEmpty);
      expect(vm.request.zoneIds, isEmpty);
      expect(vm.needsZones, isFalse);
    });

    test('community list is filtered by the chosen zone', () {
      final vm = build()
        ..setRole(UserRole.farmer)
        ..setFilterZone('z1');
      expect(vm.availableCommunities.map((c) => c['id']), ['c1']);

      vm.setCommunity('c1');
      vm.setFilterZone('z2');
      expect(vm.communityId, isNull);
    });

    test('generated password is strong, visible and fills the field', () {
      final vm = build();

      final password = vm.generatePassword();

      expect(password.length, PasswordGenerator.length);
      expect(vm.password, password);
      expect(vm.showPassword, isTrue);
    });

    test('the password is revealed once and then forgotten', () async {
      final vm = build()
        ..setRole(UserRole.farmer)
        ..fullName = 'Ana Quispe'
        ..dni = '71226316'
        ..password = 'abcdefgh';

      expect(await vm.submit(), isTrue);
      expect(vm.revealedPassword, 'abcdefgh');
      expect(vm.password, isEmpty);
      expect(vm.created!.loginHint, 'Entra con su DNI 71226316');

      vm.dismissReveal();
      expect(vm.revealedPassword, isNull);
      expect(vm.created, isNull);
    });

    test('server failures show a Spanish message and keep the form', () async {
      repository.createResult = const Result.error(
        AdminFailureException(AdminFailure.offline),
      );
      final vm = build()
        ..setRole(UserRole.farmer)
        ..fullName = 'Ana Quispe'
        ..dni = '71226316'
        ..password = 'abcdefgh';

      expect(await vm.submit(), isFalse);
      expect(vm.error, AdminFailureException.offlineMessage);
      expect(vm.created, isNull);
      expect(vm.password, 'abcdefgh');
    });
  });

  group('AdminCatalogViewModel', () {
    test('resolves reference names and sorts by sort_order', () async {
      repository.tables['zones'] = [
        {'id': 'z1', 'name': 'Piura'},
      ];
      repository.tables['communities'] = [
        {'id': 'c2', 'zone_id': 'z1', 'name': 'Zeta', 'sort_order': 1},
        {'id': 'c1', 'zone_id': 'z1', 'name': 'Beta', 'sort_order': 2},
      ];
      final vm = AdminCatalogViewModel(
        repository: repository,
        def: CatalogDefs.communities,
      );
      await _settle();

      expect(vm.rows.map((r) => r['id']), ['c2', 'c1']);
      expect(vm.subtitle(vm.rows.first), 'Piura');
      expect(vm.loading, isFalse);
      vm.dispose();
    });

    test('invalid input does not reach the repository', () async {
      final vm = AdminCatalogViewModel(
        repository: repository,
        def: CatalogDefs.zones,
      )..startCreate();

      final ok = await vm.save({'code': '', 'name': 'Piura'});

      expect(ok, isFalse);
      expect(vm.fieldErrors['code'], isNotNull);
      expect(repository.savedRows, isEmpty);
      vm.dispose();
    });

    test('saves a crop and its allowed harvest units', () async {
      final vm = AdminCatalogViewModel(
        repository: repository,
        def: CatalogDefs.crops,
      )..startCreate();

      final ok = await vm.save(
        {'code': 'PAL', 'name': 'Palta'},
        allowedUnitIds: {'u1', 'u2'},
      );

      expect(ok, isTrue);
      expect(repository.savedRows.single.row['code'], 'PAL');
      expect(repository.unitSets.single.join.table, 'crop_harvest_units');
      expect(repository.unitSets.single.units.toSet(), {'u1', 'u2'});
      vm.dispose();
    });

    test('a new setting cannot silently overwrite an existing key', () async {
      repository.tables['app_settings'] = [
        {'key': 'sync.seconds', 'value': 5},
      ];
      final vm = AdminCatalogViewModel(
        repository: repository,
        def: CatalogDefs.settings,
      );
      await _settle();
      vm.startCreate();

      final ok = await vm.save({'key': 'sync.seconds', 'value': '6'});

      expect(ok, isFalse);
      expect(vm.message, 'Ya existe un registro con ese código.');
      expect(repository.savedRows, isEmpty);
      vm.dispose();
    });
  });
}
