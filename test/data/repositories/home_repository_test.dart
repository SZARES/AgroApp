import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/home_repository.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/domain/models/home_summary.dart';
import 'package:hackathon/domain/models/incident_status.dart';

void main() {
  const farmerId = 'f1';
  late AppDatabase database;
  late LocalStore store;
  late LocalHomeRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = LocalStore(database, OutboxRepository(database));
    repository = LocalHomeRepository(store: store, farmerId: farmerId);
  });

  tearDown(() => database.close());

  Future<HomeSummary> summary() => repository.watchSummary().first;

  Map<String, dynamic> incident(String id, String status, String reportedAt) =>
      {
        'id': id,
        'farmer_id': farmerId,
        'status': status,
        'reported_at': reportedAt,
      };

  test('is empty when nothing has been synced', () async {
    expect(await summary(), HomeSummary.empty);
  });

  test('reads parcel name and location label', () async {
    await store.applyServerRows('parcels', [
      {
        'id': 'p1',
        'farmer_id': farmerId,
        'name': 'Campo del pozo',
        'latitude': -5.1,
        'longitude': -80.6,
        'created_at': '2026-01-01T00:00:00Z',
      },
      {
        'id': 'p2',
        'farmer_id': farmerId,
        'name': 'Otro',
        'created_at': '2026-02-01T00:00:00Z',
      },
      {'id': 'x', 'farmer_id': 'f2', 'name': 'Ajeno'},
    ]);
    await store.applyServerRows('farmers', [
      {'id': farmerId, 'community_id': 'c1'},
    ]);
    await store.applyServerRows('communities', [
      {'id': 'c1', 'zone_id': 'z1', 'name': 'La Matanza'},
    ]);
    await store.applyServerRows('zones', [
      {'id': 'z1', 'name': 'Morropón'},
    ]);

    final home = await summary();

    expect(home.parcelName, 'Campo del pozo');
    expect(home.parcelCount, 2);
    expect(home.hasLocation, isTrue);
    expect(home.locationLabel, 'Morropón · La Matanza');
  });

  test('derives last fertilization from the farmer own activities', () async {
    await store.applyServerRows('parcels', [
      {'id': 'p1', 'farmer_id': farmerId, 'name': 'A'},
    ]);
    await store.applyServerRows('crop_cycles', [
      {'id': 'cy1', 'parcel_id': 'p1'},
      {'id': 'cy2', 'parcel_id': 'foreign'},
    ]);
    await store.applyServerRows('activity_types', [
      {'id': 't-fert', 'code': 'fertilization'},
      {'id': 't-irr', 'code': 'irrigation'},
    ]);
    Map<String, dynamic> activity(
      String id,
      String cycle,
      String type,
      String date,
    ) => {
      'id': id,
      'crop_cycle_id': cycle,
      'activity_type_id': type,
      'activity_date': date,
    };
    await store.applyServerRows('activities', [
      activity('a1', 'cy1', 't-fert', '2026-03-01'),
      activity('a2', 'cy1', 't-fert', '2026-04-10'),
      activity('a3', 'cy1', 't-irr', '2026-05-20'),
      activity('a4', 'cy2', 't-fert', '2026-06-01'),
    ]);

    expect((await summary()).lastFertilization, DateTime(2026, 4, 10));
  });

  test(
    'next recommendation skips confirmed ones, prefers the soonest due',
    () async {
      Map<String, dynamic> rec(
        String id,
        String owner,
        String text,
        String due,
      ) => {'id': id, 'farmer_id': owner, 'description': text, 'due_date': due};
      await store.applyServerRows('recommendations', [
        rec('r1', farmerId, 'Confirmada', '2026-01-01'),
        rec('r2', farmerId, 'Podar ramas secas', '2026-05-01'),
        rec('r3', farmerId, 'Más tarde', '2026-09-01'),
        rec('r4', 'f2', 'Ajena', '2025-01-01'),
      ]);
      await store.applyServerRows('recommendation_confirmations', [
        {'id': 'c1', 'recommendation_id': 'r1'},
      ]);

      expect((await summary()).nextRecommendation, 'Podar ramas secas');
    },
  );

  test('active incident is the latest unresolved one', () async {
    await store.applyServerRows('incidents', [
      incident('i1', 'closed', '2026-06-01T00:00:00Z'),
      incident('i2', 'reported', '2026-04-01T00:00:00Z'),
      incident('i3', 'visit_scheduled', '2026-05-01T00:00:00Z'),
    ]);

    expect((await summary()).activeIncident, IncidentStatus.visitScheduled);

    await store.applyServerRows('incidents', [
      incident('i3', 'closed', '2026-05-01T00:00:00Z'),
      incident('i2', 'closed', '2026-04-01T00:00:00Z'),
    ]);
    expect((await summary()).activeIncident, isNull);
  });

  test('production sums estimated kg and counts harvests', () async {
    await store.applyServerRows('parcels', [
      {'id': 'p1', 'farmer_id': farmerId, 'name': 'A'},
    ]);
    await store.applyServerRows('harvests', [
      {'id': 'h1', 'parcel_id': 'p1', 'estimated_weight_kg': 100},
      {'id': 'h2', 'parcel_id': 'p1', 'estimated_weight_kg': '50.5'},
      {'id': 'h3', 'parcel_id': 'p1'},
      {'id': 'h4', 'parcel_id': 'foreign', 'estimated_weight_kg': 999},
    ]);

    final home = await summary();

    expect(home.harvestCount, 3);
    expect(home.productionKg, 150.5);
  });

  test('re-emits when local data changes', () async {
    final names = <String?>[];
    final sub = repository.watchSummary().listen(
      (s) => names.add(s.parcelName),
    );
    addTearDown(sub.cancel);
    await pumpEventQueue();

    await store.applyServerRows('parcels', [
      {'id': 'p1', 'farmer_id': farmerId, 'name': 'Nuevo'},
    ]);
    await pumpEventQueue();

    expect(names.first, isNull);
    expect(names.last, 'Nuevo');
  });
}
