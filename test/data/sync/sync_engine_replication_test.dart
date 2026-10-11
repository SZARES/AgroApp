import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/data/sync/sync_engine.dart';
import 'package:hackathon/domain/models/sync_op.dart';
import 'package:hackathon/domain/models/sync_status.dart';

import '../../testing/fakes.dart';

void main() {
  late AppDatabase database;
  late OutboxRepository outbox;
  late LocalStore store;
  late FakeSyncService service;
  late FakeConnectivityService connectivity;
  late SyncEngine engine;

  SyncEngine buildEngine({int pageSize = 1000}) => SyncEngine(
    repository: outbox,
    localStore: store,
    syncService: service,
    connectivity: connectivity,
    pullPageSize: pageSize,
  );

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    outbox = OutboxRepository(database);
    store = LocalStore(database, outbox);
    service = FakeSyncService();
    connectivity = FakeConnectivityService();
    engine = buildEngine();
  });

  tearDown(() async {
    await engine.dispose();
    await connectivity.close();
    await database.close();
  });

  Future<Map<String, SyncStatus>> statuses() async {
    final rows = await database.select(database.outbox).get();
    return {for (final row in rows) row.id: row.syncStatus};
  }

  Map<String, dynamic> named(String id, String updatedAt) => {
    'id': id,
    'name': id,
    'updated_at': updatedAt,
  };

  group('push', () {
    test('routes batch via sync_batch, upsert/update via PostgREST', () async {
      await store.save(
        table: 'activities',
        id: 'a1',
        row: {'q': 1},
        op: SyncOp.batch,
      );
      await store.save(
        table: 'parcels',
        id: 'p1',
        row: {'n': 'x'},
        op: SyncOp.upsert,
      );
      await store.save(
        table: 'incidents',
        id: 'i1',
        row: {'status': 'closed'},
        op: SyncOp.update,
      );

      await engine.syncNow();

      expect(service.batches.single.map((r) => r.id), ['a1']);
      expect(service.upserts.single.table, 'parcels');
      expect(service.upserts.single.row['id'], 'p1');
      expect(service.updates.single.id, 'i1');
      expect(service.updates.single.changes, {'status': 'closed'});
      expect(await statuses(), isEmpty);
      expect(await store.isPending('activities', 'a1'), isFalse);
      expect(await store.isPending('parcels', 'p1'), isFalse);
      expect(await store.isPending('incidents', 'i1'), isFalse);
    });

    test('a failing record does not abort the others', () async {
      await store.save(
        table: 'parcels',
        id: 'bad',
        row: {'n': 1},
        op: SyncOp.upsert,
      );
      await store.save(
        table: 'parcels',
        id: 'good',
        row: {'n': 2},
        op: SyncOp.upsert,
      );
      await store.save(
        table: 'incidents',
        id: 'i1',
        row: {'s': 1},
        op: SyncOp.update,
      );
      service.failingRows.add('bad');

      await engine.syncNow();

      expect(service.upserts.map((u) => u.row['id']), ['good']);
      expect(service.updates, hasLength(1));
      expect(await store.isPending('parcels', 'bad'), isTrue);
      expect(await store.isPending('parcels', 'good'), isFalse);
      final failed = (await outbox.pendingBatch()).single;
      expect(failed.status, SyncStatus.error);
      expect(failed.attempts, 1);
    });

    test('skips records past the attempt limit until a manual retry', () async {
      await store.save(
        table: 'parcels',
        id: 'bad',
        row: {'n': 1},
        op: SyncOp.upsert,
      );
      service.failingRows.add('bad');
      for (var i = 0; i < 5; i++) {
        await engine.syncNow();
      }
      service.failingRows.clear();

      await engine.syncNow();
      expect(service.upserts, isEmpty);

      await engine.syncNow(retryFailed: true);
      expect(service.upserts, hasLength(1));
    });
  });

  group('pull', () {
    test(
      'applies rows, persists the cursor, asks only for newer rows',
      () async {
        service.serverRows['zones'] = [
          named('z1', '2026-01-01T00:00:00Z'),
          named('z2', '2026-01-02T00:00:00Z'),
        ];

        await engine.syncNow(forcePull: true);

        expect(
          (await store.list('zones')).map((r) => r['id']),
          unorderedEquals(['z1', 'z2']),
        );
        expect(await store.readCursor('zones'), DateTime.utc(2026, 1, 2));

        service.serverRows['zones']!.add(named('z3', '2026-01-03T00:00:00Z'));
        service.pulls.clear();
        await engine.syncNow(forcePull: true);

        final zonePull = service.pulls.firstWhere((p) => p.table == 'zones');
        expect(zonePull.since, DateTime.utc(2026, 1, 2));
        expect(await store.list('zones'), hasLength(3));
      },
    );

    test('pages until a short page is returned', () async {
      engine = buildEngine(pageSize: 2);
      service.serverRows['crops'] = [
        for (var i = 1; i <= 5; i++) named('c$i', '2026-01-0${i}T00:00:00Z'),
      ];

      await engine.syncNow(forcePull: true);

      expect(await store.list('crops'), hasLength(5));
      expect(service.pulls.where((p) => p.table == 'crops'), hasLength(3));
      expect(await store.readCursor('crops'), DateTime.utc(2026, 1, 5));
    });

    test('incident history is pulled by changed_at', () async {
      service.serverRows['incident_status_history'] = [
        {'id': 'h1', 'changed_at': '2026-01-01T00:00:00Z'},
      ];

      await engine.syncNow(forcePull: true);

      expect(await store.list('incident_status_history'), hasLength(1));
      expect(
        await store.readCursor('incident_status_history'),
        DateTime.utc(2026),
      );
    });

    test('join tables are fully refreshed', () async {
      service.serverRows['product_units'] = [
        {'product_id': 'p1', 'unit_id': 'u1'},
        {'product_id': 'p1', 'unit_id': 'u2'},
      ];
      await engine.syncNow(forcePull: true);
      expect(await store.list('product_units'), hasLength(2));

      service.serverRows['product_units'] = [
        {'product_id': 'p1', 'unit_id': 'u2'},
      ];
      await engine.syncNow(forcePull: true);

      final rows = await store.list('product_units');
      expect(rows.single['unit_id'], 'u2');
      expect(await store.get('product_units', 'p1|u2'), isNotNull);
    });

    test('a failing table does not block the others', () async {
      service.failingPulls.add('zones');
      service.serverRows['crops'] = [named('c1', '2026-01-01T00:00:00Z')];

      await engine.syncNow(forcePull: true);

      expect(await store.list('crops'), hasLength(1));
      expect(await store.readCursor('zones'), isNull);
    });

    test('never overwrites a row with unsent local changes', () async {
      await store.save(
        table: 'parcels',
        id: 'p1',
        row: {'name': 'local'},
        op: SyncOp.upsert,
      );
      service.failingRows.add('p1');
      service.serverRows['parcels'] = [
        {'id': 'p1', 'name': 'server', 'updated_at': '2026-01-01T00:00:00Z'},
      ];

      await engine.syncNow(forcePull: true);

      expect((await store.get('parcels', 'p1'))!['name'], 'local');
    });

    test('is skipped while offline', () async {
      connectivity.online = false;

      await engine.syncNow(forcePull: true);

      expect(service.pulls, isEmpty);
      expect(engine.snapshot.isOnline, isFalse);
    });
  });

  test('snapshot reports counts and the last sync time', () async {
    await store.save(
      table: 'parcels',
      id: 'bad',
      row: {'n': 1},
      op: SyncOp.upsert,
    );
    service.failingRows.add('bad');

    await engine.syncNow(forcePull: true);

    expect(engine.snapshot.failedCount, 1);
    expect(engine.snapshot.pendingCount, 0);
    expect(engine.snapshot.isSyncing, isFalse);
    expect(engine.snapshot.lastSyncedAt, isNotNull);
  });

  test('resetForNewUser wipes local data and pull cursors', () async {
    service.serverRows['zones'] = [named('z1', '2026-01-01T00:00:00Z')];
    await store.save(
      table: 'parcels',
      id: 'p',
      row: {'n': 1},
      op: SyncOp.batch,
    );
    await engine.syncNow(forcePull: true);

    await engine.resetForNewUser();

    expect(await store.list('zones'), isEmpty);
    expect(await store.list('parcels'), isEmpty);
    expect(await outbox.pendingBatch(), isEmpty);
    expect(await store.readCursor('zones'), isNull);
  });
}
