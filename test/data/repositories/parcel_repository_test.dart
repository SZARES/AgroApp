import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/data/repositories/parcel_repository.dart';
import 'package:hackathon/domain/models/geo_point.dart';
import 'package:hackathon/domain/models/parcel_failure.dart';
import 'package:hackathon/domain/models/sync_op.dart';
import 'package:hackathon/domain/models/sync_status.dart';
import 'package:hackathon/utils/result.dart';

void main() {
  const farmerId = 'f1';
  late AppDatabase database;
  late OutboxRepository outbox;
  late LocalStore store;
  late LocalParcelRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    outbox = OutboxRepository(database);
    store = LocalStore(database, outbox);
    repository = LocalParcelRepository(store: store, farmerId: farmerId);
  });

  tearDown(() => database.close());

  Future<void> seedServerParcel(
    String id, {
    String owner = farmerId,
    String name = 'Campo del pozo',
    Map<String, dynamic> extra = const {},
  }) => store.applyServerRows('parcels', [
    {
      'id': id,
      'farmer_id': owner,
      'zone_id': 'z1',
      'name': name,
      'area': 1.2,
      'active': true,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      ...extra,
    },
  ]);

  group('watchParcels', () {
    test(
      'lists only the farmer parcels with polygon, crop and incidents',
      () async {
        await seedServerParcel(
          'p1',
          extra: {
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [-80.0, -5.0],
                  [-79.9, -5.0],
                  [-79.9, -5.1],
                  [-80.0, -5.0],
                ],
              ],
            },
          },
        );
        await seedServerParcel('other', owner: 'f2', name: 'Ajeno');
        await store.applyServerRows('crops', [
          {'id': 'c1', 'name': 'Limón'},
        ]);
        await store.applyServerRows('crop_cycles', [
          {'id': 'cy1', 'parcel_id': 'p1', 'crop_id': 'c1', 'status': 'active'},
        ]);
        await store.applyServerRows('incidents', [
          {
            'id': 'i1',
            'parcel_id': 'p1',
            'farmer_id': farmerId,
            'status': 'reported',
          },
          {
            'id': 'i2',
            'parcel_id': 'p1',
            'farmer_id': farmerId,
            'status': 'closed',
          },
        ]);

        final parcels = await repository.watchParcels().first;

        expect(parcels.map((p) => p.name), ['Campo del pozo']);
        expect(parcels.single.polygon, hasLength(3));
        expect(parcels.single.cropName, 'Limón');
        expect(parcels.single.openIncidents, 1);
        expect(parcels.single.pendingSync, isFalse);
      },
    );

    test('emits again when a parcel is added', () async {
      final emissions = <int>[];
      final sub = repository.watchParcels().listen(
        (parcels) => emissions.add(parcels.length),
      );
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await seedServerParcel('p1');
      await pumpEventQueue();

      expect(emissions.first, 0);
      expect(emissions.last, 1);
    });
  });

  group('addParcel', () {
    test('saves locally with a UUID and queues an upsert', () async {
      await seedServerParcel('p1');

      final result = await repository.addParcel(
        name: '  Campo nuevo ',
        areaHectares: 1.5,
        location: const GeoPoint(latitude: -5.19, longitude: -80.63),
      );

      final parcel = (result as Ok<dynamic>).value;
      expect(parcel.name, 'Campo nuevo');
      expect(parcel.id, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(parcel.pendingSync, isTrue);

      final row = await store.get('parcels', parcel.id as String);
      expect(row, containsPair('farmer_id', farmerId));
      expect(row, containsPair('zone_id', 'z1'));
      expect(row, containsPair('latitude', -5.19));
      expect(await store.isPending('parcels', parcel.id as String), isTrue);

      final queued = (await outbox.pendingBatch()).single;
      expect(queued.op, SyncOp.upsert);
      expect(queued.tableName, 'parcels');
      expect(queued.payload['id'], parcel.id);
      expect(queued.payload['name'], 'Campo nuevo');
      final stored = await database.select(database.outbox).getSingle();
      expect(stored.syncStatus, SyncStatus.pending);
    });

    test('uses the hectare unit and the community zone when known', () async {
      await store.applyServerRows('units', [
        {'id': 'u-ha', 'abbreviation': 'ha'},
        {'id': 'u-m2', 'abbreviation': 'm2'},
      ]);
      await store.applyServerRows('farmers', [
        {'id': farmerId, 'community_id': 'c1'},
      ]);
      await store.applyServerRows('communities', [
        {'id': 'c1', 'zone_id': 'z9'},
      ]);

      final result = await repository.addParcel(name: 'A', areaHectares: 2);

      final id = (result as Ok<dynamic>).value.id as String;
      final row = await store.get('parcels', id);
      expect(row, containsPair('area_unit_id', 'u-ha'));
      expect(row, containsPair('zone_id', 'z9'));
      expect(row!.containsKey('latitude'), isFalse);
    });

    test('rejects blank name, bad area and unknown zone', () async {
      await seedServerParcel('p1');
      Future<Object> failure(String name, double area) async =>
          ((await repository.addParcel(name: name, areaHectares: area))
                  as Error<dynamic>)
              .error;

      expect(await failure('  ', 1), ParcelFailure.invalidName);
      expect(await failure('A', 0), ParcelFailure.invalidArea);
      expect(await failure('A', double.nan), ParcelFailure.invalidArea);
      expect(await outbox.pendingBatch(), isEmpty);

      final noZone = LocalParcelRepository(store: store, farmerId: 'nobody');
      final result = await noZone.addParcel(name: 'A', areaHectares: 1);
      expect((result as Error<dynamic>).error, ParcelFailure.noZone);
    });
  });
}
