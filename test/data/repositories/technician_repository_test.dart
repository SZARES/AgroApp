import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/data/repositories/technician_repository.dart';
import 'package:hackathon/domain/models/sync_op.dart';
import 'package:hackathon/domain/models/technician_case.dart';
import 'package:hackathon/utils/result.dart';

void main() {
  late AppDatabase database;
  late OutboxRepository outbox;
  late LocalStore store;
  late LocalTechnicianRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    outbox = OutboxRepository(database);
    store = LocalStore(database, outbox);
    repository = LocalTechnicianRepository(
      store: store,
      technicianId: 'tech1',
      photoUrlResolver: (_) async => null,
      clock: () => DateTime(2026, 10, 11, 10),
    );
  });

  tearDown(() => database.close());

  Future<void> seed() async {
    await store.applyServerRows('profiles', [
      {'id': 'u1', 'full_name': 'Rosa Quispe', 'phone': '999111222'},
      {'id': 'u2', 'full_name': 'Abel Ramos'},
      {'id': 'u3', 'full_name': 'Aaron Zapata'},
    ]);
    await store.applyServerRows('communities', [
      {'id': 'c1', 'name': 'Chulucanas'},
    ]);
    await store.applyServerRows('farmers', [
      {'id': 'f1', 'user_id': 'u1', 'community_id': 'c1', 'active': true},
      {'id': 'f2', 'user_id': 'u2', 'active': true},
      {'id': 'f3', 'user_id': 'u3', 'active': true},
    ]);
    await store.applyServerRows('parcels', [
      {'id': 'p1', 'farmer_id': 'f1', 'name': 'Campo alto', 'area': 2.0},
      {'id': 'p2', 'farmer_id': 'f1', 'name': 'Campo bajo', 'area': 1.5},
      {'id': 'p3', 'farmer_id': 'f2', 'name': 'Ajena', 'area': 1.0},
    ]);
    await store.applyServerRows('crops', [
      {'id': 'cr1', 'name': 'Limón'},
    ]);
    await store.applyServerRows('crop_cycles', [
      {'id': 'cy1', 'parcel_id': 'p1', 'crop_id': 'cr1', 'status': 'active'},
    ]);
    await store.applyServerRows('symptom_types', [
      {'id': 's1', 'name': 'Hojas amarillas'},
    ]);
    await store.applyServerRows('incidents', [
      {
        'id': 'i1',
        'farmer_id': 'f1',
        'parcel_id': 'p1',
        'crop_id': 'cr1',
        'symptom_type_id': 's1',
        'status': 'reported',
        'priority': 'high',
        'reported_at': '2026-10-01T08:00:00Z',
      },
      {
        'id': 'i2',
        'farmer_id': 'f1',
        'parcel_id': 'p2',
        'symptom_type_id': 's1',
        'status': 'closed',
        'priority': 'low',
        'reported_at': '2026-09-01T08:00:00Z',
      },
      {
        'id': 'i3',
        'farmer_id': 'f2',
        'parcel_id': 'p3',
        'symptom_type_id': 's1',
        'status': 'attended',
        'priority': 'medium',
        'reported_at': '2026-09-20T08:00:00Z',
      },
    ]);
    await store.applyServerRows('incident_status_history', [
      {
        'id': 'h1',
        'incident_id': 'i3',
        'old_status': 'reported',
        'new_status': 'under_review',
        'changed_at': '2026-09-21T08:00:00Z',
      },
      {
        'id': 'h2',
        'incident_id': 'i3',
        'old_status': 'under_review',
        'new_status': 'attended',
        'changed_at': '2026-09-25T08:00:00Z',
      },
    ]);
    await store.applyServerRows('assistance_categories', [
      {'id': 'cat1', 'name': 'Visita técnica', 'sort_order': 1},
    ]);
    await store.applyServerRows('technical_assistance', [
      {
        'id': 'a1',
        'farmer_id': 'f1',
        'parcel_id': 'p1',
        'incident_id': 'i1',
        'status': 'scheduled',
        'topic': 'Visita programada',
        'assistance_date': '2026-10-15',
      },
      {
        'id': 'a2',
        'farmer_id': 'f1',
        'parcel_id': 'p2',
        'status': 'completed',
        'topic': 'Poda',
        'assistance_date': '2026-09-10',
      },
    ]);
    await store.applyServerRows('recommendations', [
      {'id': 'r1', 'assistance_id': 'a2', 'farmer_id': 'f1', 'description': 'x'},
      {'id': 'r2', 'assistance_id': 'a2', 'farmer_id': 'f1', 'description': 'y'},
    ]);
    await store.applyServerRows('recommendation_confirmations', [
      {'id': 'rc1', 'recommendation_id': 'r1', 'farmer_id': 'f1'},
    ]);
  }

  group('watchFarmers', () {
    test('lists farmers with counts, open cases first', () async {
      await seed();

      final farmers = await repository.watchFarmers().first;

      // Open cases first, then by name.
      expect(farmers.map((f) => f.name), [
        'Abel Ramos',
        'Rosa Quispe',
        'Aaron Zapata',
      ]);
      final rosa = farmers[1];
      expect(rosa.id, 'f1');
      expect(rosa.phone, '999111222');
      expect(rosa.communityName, 'Chulucanas');
      expect(rosa.parcelCount, 2);
      expect(rosa.openCaseCount, 1);
      expect(rosa.lastAssistanceDate, DateTime.parse('2026-10-15'));
      // An attended case is still open (only closed ones are not).
      expect(farmers.first.openCaseCount, 1);
      expect(farmers.last.openCaseCount, 0);
    });

    test('is empty when nothing was synced', () async {
      expect(await repository.watchFarmers().first, isEmpty);
    });
  });

  group('watchFarmer', () {
    test('builds the file: parcels, cases, assistances, recommendations',
        () async {
      await seed();

      final detail = (await repository.watchFarmer('f1').first)!;

      expect(detail.farmer.name, 'Rosa Quispe');
      expect(detail.parcels.map((p) => p.name), ['Campo alto', 'Campo bajo']);
      expect(detail.parcels.first.cropName, 'Limón');
      expect(detail.parcels.first.openIncidents, 1);
      expect(detail.cases.map((c) => c.id), ['i1', 'i2']);
      expect(detail.assistances.map((a) => a.id), ['a1', 'a2']);
      expect(detail.assistances.first.isScheduled, isTrue);
      expect(detail.assistances.last.parcelName, 'Campo bajo');
      expect(detail.recommendations.issued, 2);
      expect(detail.recommendations.confirmed, 1);
    });

    test('emits null for a farmer that is not in the replica', () async {
      await seed();

      expect(await repository.watchFarmer('nope').first, isNull);
    });
  });

  group('watchKpis', () {
    test('computes the dashboard numbers from the replica', () async {
      await seed();

      final kpis = await repository.watchKpis().first;

      expect(kpis.openAlerts, 2); // reported + attended
      expect(kpis.urgentAlerts, 1);
      expect(kpis.attendedCases, 1);
      expect(kpis.closedCases, 1);
      expect(kpis.scheduledVisits, 1);
      expect(kpis.activeFarmers, 3);
      expect(kpis.recommendationsIssued, 2);
      expect(kpis.recommendationsConfirmed, 1);
      // i3 was first handled one day after being reported.
      expect(kpis.avgResponseDays, closeTo(1, 0.001));
    });

    test('has no average response time without handled cases', () async {
      final kpis = await repository.watchKpis().first;

      expect(kpis.openAlerts, 0);
      expect(kpis.avgResponseDays, isNull);
    });
  });

  group('registerFieldAssistance', () {
    const draft = AssistanceDraft(
      categoryId: 'cat1',
      observation: 'Revisé el riego',
      recommendation: 'Regar cada 3 días',
    );

    test('saves an assistance without incident and queues it', () async {
      await seed();

      final result = await repository.registerFieldAssistance(
        farmerId: 'f1',
        parcelId: 'p2',
        draft: draft,
      );

      expect(result, isA<Ok<void>>());
      final rows = await store.list(
        'technical_assistance',
        where: (a) => a['topic'] == 'Visita técnica',
      );
      final row = rows.single;
      expect(row.containsKey('incident_id'), isFalse);
      expect(row['farmer_id'], 'f1');
      expect(row['parcel_id'], 'p2');
      expect(row['provider'], 'AIDER');
      expect(row['technician_id'], 'tech1');
      expect(row['created_by'], 'tech1');
      expect(row['status'], 'completed');
      expect(row['assistance_date'], '2026-10-11');
      expect(await store.isPending('technical_assistance', '${row['id']}'),
          isTrue);

      final queued = await outbox.pendingBatch();
      expect(queued.map((q) => q.tableName).toSet(), {
        'technical_assistance',
        'recommendations',
      });
      final assistance = queued.firstWhere(
        (q) => q.tableName == 'technical_assistance',
      );
      expect(assistance.op, SyncOp.upsert);
      expect(assistance.payload.containsKey('incident_id'), isFalse);
      final recommendation = queued.firstWhere(
        (q) => q.tableName == 'recommendations',
      );
      expect(recommendation.payload['assistance_id'], row['id']);
      expect(recommendation.payload['farmer_id'], 'f1');
      expect(recommendation.payload['parcel_id'], 'p2');
    });

    test('the new assistance shows in the farmer file', () async {
      await seed();
      await repository.registerFieldAssistance(
        farmerId: 'f1',
        parcelId: 'p1',
        draft: draft,
      );

      final detail = (await repository.watchFarmer('f1').first)!;

      final added = detail.assistances.singleWhere(
        (a) => a.topic == 'Visita técnica',
      );
      expect(added.isPending, isTrue);
      expect(added.parcelName, 'Campo alto');
      expect(detail.recommendations.issued, 3);
    });

    test('refuses unknown farmers and parcels of another farmer', () async {
      await seed();

      final unknown = await repository.registerFieldAssistance(
        farmerId: 'nope',
        draft: draft,
      );
      final foreignParcel = await repository.registerFieldAssistance(
        farmerId: 'f1',
        parcelId: 'p3',
        draft: draft,
      );

      for (final result in [unknown, foreignParcel]) {
        expect(
          ((result as Error<void>).error as TechnicianException).failure,
          TechnicianFailure.farmerNotFound,
        );
      }
      expect(await outbox.pendingBatch(), isEmpty);
    });

    test('refuses an empty observation and a missing category', () async {
      await seed();

      final empty = await repository.registerFieldAssistance(
        farmerId: 'f1',
        draft: const AssistanceDraft(categoryId: 'cat1', observation: '  '),
      );
      final noCategory = await repository.registerFieldAssistance(
        farmerId: 'f1',
        draft: const AssistanceDraft(categoryId: 'zzz', observation: 'Algo'),
      );

      expect(
        ((empty as Error<void>).error as TechnicianException).failure,
        TechnicianFailure.emptyText,
      );
      expect(
        ((noCategory as Error<void>).error as TechnicianException).failure,
        TechnicianFailure.noCategory,
      );
      expect(await outbox.pendingBatch(), isEmpty);
    });
  });
}
