import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/sync/sync_tables.dart';
import 'package:hackathon/domain/models/admin/audit_log_entry.dart';
import 'package:hackathon/domain/models/admin/catalog_defs.dart';
import 'package:hackathon/domain/models/admin/catalog_row_parser.dart';
import 'package:hackathon/domain/models/admin/create_user_request.dart';
import 'package:hackathon/domain/models/admin/field_def.dart';
import 'package:hackathon/domain/models/admin/password_generator.dart';
import 'package:hackathon/domain/models/user_role.dart';

/// Columns that exist in the deployed schema (checked against the database).
const _columns = <String, Set<String>>{
  'zones': {'id', 'code', 'name', 'active', 'sort_order'},
  'communities': {'id', 'zone_id', 'name', 'active', 'sort_order'},
  'crops': {'id', 'code', 'name', 'active', 'sort_order'},
  'units': {'id', 'name', 'abbreviation', 'category', 'active', 'sort_order'},
  'products': {'id', 'name', 'category', 'form', 'active', 'sort_order'},
  'activity_types': {
    'id',
    'code',
    'name',
    'requires_product',
    'requires_pruning_type',
    'active',
    'sort_order',
  },
  'pruning_types': {'id', 'code', 'name', 'active', 'sort_order'},
  'symptom_types': {'id', 'code', 'name', 'active', 'sort_order'},
  'assistance_categories': {'id', 'code', 'name', 'active', 'sort_order'},
  'assistance_subtypes': {
    'id',
    'category_id',
    'code',
    'name',
    'active',
    'sort_order',
  },
  'expense_categories': {'id', 'code', 'name', 'active', 'sort_order'},
  'buyers': {
    'id',
    'name',
    'location',
    'zone_id',
    'phone',
    'type',
    'active',
    'sort_order',
  },
  'reference_prices': {
    'id',
    'crop_id',
    'unit_id',
    'price',
    'currency',
    'valid_from',
    'valid_to',
    'notes',
    'active',
    'sort_order',
  },
  'unit_equivalences': {
    'id',
    'crop_id',
    'unit_id',
    'kg_per_unit',
    'validated',
    'validated_by',
    'validated_at',
    'notes',
  },
  'app_settings': {'key', 'value', 'description'},
};

void main() {
  final replicated = {for (final t in SyncTables.pullTables) t.name};

  group('CatalogDefs registry', () {
    test('every def targets a known, replicated table and real columns', () {
      for (final def in CatalogDefs.all) {
        final columns = _columns[def.table];
        expect(columns, isNotNull, reason: def.table);
        expect(replicated, contains(def.table), reason: def.table);
        for (final field in def.fields) {
          expect(columns, contains(field.column), reason: def.table);
        }
        expect(columns, contains(def.idColumn), reason: def.table);
        expect(columns, contains(def.titleColumn), reason: def.table);
        for (final column in def.subtitleColumns) {
          expect(columns, contains(column), reason: def.table);
        }
        expect(columns!.contains('active'), def.hasActive, reason: def.table);
        expect(
          columns.contains('sort_order'),
          def.hasSortOrder,
          reason: def.table,
        );
      }
    });

    test('reference fields point to replicated tables', () {
      for (final def in CatalogDefs.all) {
        for (final field in def.fields) {
          if (field.kind == FieldKind.reference) {
            expect(field.referenceTable, isNotNull);
            expect(replicated, contains(field.referenceTable));
          }
          if (field.kind == FieldKind.dropdown) {
            expect(field.options, isNotEmpty);
          }
        }
      }
    });

    test('allowed-unit joins are replicated tables', () {
      final joins = [
        for (final def in CatalogDefs.all)
          if (def.allowedUnits != null) def.allowedUnits!.table,
      ];
      expect(
        joins,
        unorderedEquals([
          'crop_harvest_units',
          'activity_type_units',
          'product_units',
        ]),
      );
      expect(replicated, containsAll(joins));
    });

    test('ids are unique and sections cover every catalog', () {
      final ids = [for (final def in CatalogDefs.all) def.id];
      expect(ids.toSet().length, ids.length);
      final inSections = [for (final s in CatalogDefs.sections) ...s.catalogs];
      expect(inSections.toSet(), CatalogDefs.all.toSet());
      expect(CatalogDefs.sections.first.id, 'users');
      expect(CatalogDefs.sections.last.id, 'audit');
    });

    test('settings use the key as id', () {
      expect(CatalogDefs.settings.usesKeyAsId, isTrue);
      expect(CatalogDefs.zones.usesKeyAsId, isFalse);
    });
  });

  group('CatalogRowParser', () {
    test('requires required fields and parses numbers with a comma', () {
      final bad = CatalogRowParser.parse(CatalogDefs.referencePrices, {});
      expect(bad.errors.keys, containsAll(['crop_id', 'unit_id', 'price']));

      final ok = CatalogRowParser.parse(CatalogDefs.referencePrices, {
        'crop_id': 'c',
        'unit_id': 'u',
        'price': '2,5',
        'valid_from': '2026-03-01',
        'sort_order': '3',
      });
      expect(ok.isValid, isTrue);
      expect(ok.row['price'], 2.5);
      expect(ok.row['sort_order'], 3);
      expect(ok.row['notes'], isNull);
    });

    test('rejects non-positive kilos and invalid JSON', () {
      final kg = CatalogRowParser.parse(CatalogDefs.unitEquivalences, {
        'unit_id': 'u',
        'kg_per_unit': '0',
      });
      expect(kg.errors['kg_per_unit'], isNotNull);

      final json = CatalogRowParser.parse(CatalogDefs.settings, {
        'key': 'k',
        'value': '{not json',
      });
      expect(json.errors['value'], 'JSON no válido');

      final okJson = CatalogRowParser.parse(CatalogDefs.settings, {
        'key': 'k',
        'value': '{"a": 1}',
      });
      expect(okJson.row['value'], {'a': 1});
    });

    test('dropdown must be one of the options', () {
      final bad = CatalogRowParser.parse(CatalogDefs.units, {
        'name': 'Saco',
        'abbreviation': 'sc',
        'category': 'nope',
      });
      expect(bad.errors['category'], isNotNull);
    });
  });

  group('CreateUserRequest', () {
    test('farmer payload has dni and no email', () {
      const request = CreateUserRequest(
        role: UserRole.farmer,
        fullName: ' Ana Quispe ',
        password: 'abcdefgh',
        dni: '71226316',
        email: 'ignored@x.pe',
        communityId: 'c1',
        ageRange: '30-39',
      );
      expect(request.validate(), isEmpty);
      final json = request.toJson();
      expect(json['dni'], '71226316');
      expect(json.containsKey('email'), isFalse);
      expect(json['full_name'], 'Ana Quispe');
      expect(json['role'], 'farmer');
      expect(json['community_id'], 'c1');
      expect(json['age_range'], '30-39');
      expect(json.containsKey('zone_ids'), isFalse);
    });

    test('staff payload has email and zones, no dni', () {
      const request = CreateUserRequest(
        role: UserRole.technician,
        fullName: 'Luis Rojas',
        password: 'abcdefgh',
        email: 'Luis@Aider.PE',
        zoneIds: ['z1'],
      );
      expect(request.validate(), isEmpty);
      final json = request.toJson();
      expect(json['email'], 'luis@aider.pe');
      expect(json['zone_ids'], ['z1']);
      expect(json.containsKey('dni'), isFalse);
    });

    test('validates per role', () {
      const farmer = CreateUserRequest(
        role: UserRole.farmer,
        fullName: 'A',
        password: 'short',
        dni: '123',
      );
      expect(
        farmer.validate().keys,
        containsAll([
          UserFormField.fullName,
          UserFormField.password,
          UserFormField.dni,
        ]),
      );
      const staff = CreateUserRequest(
        role: UserRole.admin,
        fullName: 'Ana Quispe',
        password: 'abcdefgh',
        email: 'x@agricultores.agroapp',
      );
      expect(staff.validate()[UserFormField.email], isNotNull);
    });
  });

  group('PasswordGenerator', () {
    test('makes 12 chars from the charset with every class', () {
      for (var i = 0; i < 50; i++) {
        final password = PasswordGenerator.generate(random: Random(i));
        expect(password.length, 12);
        expect(
          password.split('').every(PasswordGenerator.charset.contains),
          isTrue,
        );
        expect(password, matches(RegExp('[a-z]')));
        expect(password, matches(RegExp('[A-Z]')));
        expect(password, matches(RegExp('[0-9]')));
        expect(password, matches(RegExp(r'[!@#$%*?]')));
      }
    });

    test('secure generator gives different passwords', () {
      expect(PasswordGenerator.generate(), isNot(PasswordGenerator.generate()));
    });
  });

  group('AuditLogEntry', () {
    test('diffs old and new data, skipping timestamps', () {
      final entry = AuditLogEntry.tryFromRow({
        'id': 'a1',
        'actor_id': 'u1',
        'action': 'UPDATE',
        'table_name': 'zones',
        'record_id': 'z1',
        'created_at': '2026-05-01T10:00:00Z',
        'old_data': {'name': 'Piura', 'active': true, 'updated_at': 'x'},
        'new_data': {'name': 'Piura Norte', 'active': true, 'updated_at': 'y'},
      })!;
      expect(entry.changes.length, 1);
      expect(entry.changes.single.field, 'name');
      expect(entry.changes.single.before, 'Piura');
      expect(entry.changes.single.after, 'Piura Norte');
      expect(auditActionLabel('UPDATE'), 'Modificó');
    });

    test('insert lists every new field', () {
      final entry = AuditLogEntry.tryFromRow({
        'id': 'a2',
        'action': 'INSERT',
        'table_name': 'crops',
        'record_id': 'c1',
        'created_at': '2026-05-01T10:00:00Z',
        'old_data': null,
        'new_data': {'name': 'Palta', 'sort_order': 2},
      })!;
      expect(entry.actorId, isNull);
      expect(entry.changes.map((c) => c.field), ['name', 'sort_order']);
      expect(entry.changes.last.after, '2');
    });
  });
}
