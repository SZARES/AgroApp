import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/domain/models/sync_op.dart';
import 'package:hackathon/domain/models/sync_status.dart';

void main() {
  late AppDatabase database;
  late OutboxRepository outbox;
  late LocalStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    outbox = OutboxRepository(database);
    store = LocalStore(database, outbox);
  });

  tearDown(() => database.close());

  test('newId returns distinct UUID v4 values', () {
    final a = store.newId();
    expect(a, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(store.newId(), isNot(a));
  });

  group('save', () {
    test('writes the pending replica row and the outbox record', () async {
      final id = store.newId();

      final delivery = await store.save(
        table: 'activities',
        id: id,
        row: {'activity_type': 'irrigation', 'quantity': 2},
        op: SyncOp.batch,
      );

      expect(delivery, SaveDelivery.queuedOffline);
      final row = await store.get('activities', id);
      expect(row, {'id': id, 'activity_type': 'irrigation', 'quantity': 2});
      expect(await store.isPending('activities', id), isTrue);

      final queued = (await outbox.pendingBatch()).single;
      expect(queued.id, id);
      expect(queued.op, SyncOp.batch);
      expect(queued.tableName, 'activities');
      expect(queued.payload['quantity'], 2);
    });

    test('sends online when commit succeeds and skips the outbox', () async {
      final onlineStore = LocalStore(database, outbox);
      final pushed = <String>[];
      onlineStore.attachOnlineCommit(({
        required table,
        required id,
        required payload,
        required op,
      }) async {
        pushed.add('$table:$id');
        return true;
      });

      final id = onlineStore.newId();
      final delivery = await onlineStore.save(
        table: 'activities',
        id: id,
        row: {'q': 1},
        op: SyncOp.batch,
      );

      expect(delivery, SaveDelivery.sentOnline);
      expect(pushed, ['activities:$id']);
      expect(await onlineStore.isPending('activities', id), isFalse);
      expect(await outbox.pendingBatch(), isEmpty);
    });

    test('queues the outbox when the online push fails', () async {
      final onlineStore = LocalStore(database, outbox);
      onlineStore.attachOnlineCommit(({
        required table,
        required id,
        required payload,
        required op,
      }) async {
        throw StateError('offline mid-flight');
      });

      final id = onlineStore.newId();
      final delivery = await onlineStore.save(
        table: 'parcels',
        id: id,
        row: {'name': 'X'},
        op: SyncOp.upsert,
      );

      expect(delivery, SaveDelivery.queuedOffline);
      expect(await onlineStore.isPending('parcels', id), isTrue);
      expect(await outbox.pendingBatch(), hasLength(1));
    });

    test('queues the outbox when commit returns false', () async {
      final onlineStore = LocalStore(database, outbox);
      onlineStore.attachOnlineCommit(({
        required table,
        required id,
        required payload,
        required op,
      }) async => false);

      final id = onlineStore.newId();
      final delivery = await onlineStore.save(
        table: 'parcels',
        id: id,
        row: {'name': 'Y'},
        op: SyncOp.upsert,
      );

      expect(delivery, SaveDelivery.queuedOffline);
      expect(await outbox.pendingBatch(), hasLength(1));
    });

    test('rolls back the replica when the outbox write fails', () async {
      final id = store.newId();
      await database.customStatement('DROP TABLE outbox');

      await expectLater(
        store.save(
          table: 'activities',
          id: id,
          row: {'a': 1},
          op: SyncOp.batch,
        ),
        throwsA(anything),
      );

      expect(await store.get('activities', id), isNull);
    });

    test('merges into the existing row; update sends only changes', () async {
      await store.applyServerRows('incidents', [
        {
          'id': 'i1',
          'status': 'open',
          'title': 'Pest',
          'updated_at': '2026-01-01T00:00:00Z',
        },
      ]);

      await store.save(
        table: 'incidents',
        id: 'i1',
        row: {'status': 'in_review'},
        op: SyncOp.update,
      );

      expect(await store.get('incidents', 'i1'), {
        'id': 'i1',
        'status': 'in_review',
        'title': 'Pest',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      final queued = (await outbox.pendingBatch()).single;
      expect(queued.op, SyncOp.update);
      expect(queued.id, isNot('i1'));
      expect(queued.payload, {'id': 'i1', 'status': 'in_review'});
    });

    test('several updates of one row keep separate outbox records', () async {
      await store.save(
        table: 'incidents',
        id: 'i1',
        row: {'a': 1},
        op: SyncOp.update,
      );
      await store.save(
        table: 'incidents',
        id: 'i1',
        row: {'b': 2},
        op: SyncOp.update,
      );

      expect(await outbox.pendingBatch(), hasLength(2));
    });
  });

  group('applyServerRows', () {
    test('overwrites non-pending rows and skips pending ones', () async {
      await store.applyServerRows('parcels', [
        {'id': 'p1', 'name': 'old', 'updated_at': '2026-01-01T00:00:00Z'},
        {'id': 'p2', 'name': 'old', 'updated_at': '2026-01-01T00:00:00Z'},
      ]);
      await store.save(
        table: 'parcels',
        id: 'p2',
        row: {'name': 'local'},
        op: SyncOp.upsert,
      );

      await store.applyServerRows('parcels', [
        {'id': 'p1', 'name': 'new', 'updated_at': '2026-02-01T00:00:00Z'},
        {'id': 'p2', 'name': 'server', 'updated_at': '2026-02-01T00:00:00Z'},
      ]);

      expect((await store.get('parcels', 'p1'))!['name'], 'new');
      expect((await store.get('parcels', 'p2'))!['name'], 'local');
      expect(await store.isPending('parcels', 'p2'), isTrue);
    });
  });

  group('soft delete', () {
    test(
      'server rows with deleted_at are hidden from list and watch',
      () async {
        await store.applyServerRows('crops', [
          {'id': 'c1', 'updated_at': '2026-01-01T00:00:00Z'},
          {
            'id': 'c2',
            'updated_at': '2026-01-01T00:00:00Z',
            'deleted_at': '2026-01-02T00:00:00Z',
          },
        ]);

        expect((await store.list('crops')).map((r) => r['id']), ['c1']);
        expect((await store.watchTable('crops').first).map((r) => r['id']), [
          'c1',
        ]);
        expect(await store.get('crops', 'c2'), isNotNull);
      },
    );

    test('softDelete hides the row and queues an update', () async {
      await store.applyServerRows('crops', [
        {'id': 'c1', 'updated_at': '2026-01-01T00:00:00Z'},
      ]);

      await store.softDelete(table: 'crops', id: 'c1');

      expect(await store.list('crops'), isEmpty);
      final queued = (await outbox.pendingBatch()).single;
      expect(queued.op, SyncOp.update);
      expect(queued.payload.keys, containsAll(['id', 'deleted_at']));
    });
  });

  test('list and watchTable apply the where filter', () async {
    await store.applyServerRows('parcels', [
      {'id': 'a', 'zone': 1, 'updated_at': '2026-01-01T00:00:00Z'},
      {'id': 'b', 'zone': 2, 'updated_at': '2026-01-01T00:00:00Z'},
    ]);

    bool zoneTwo(Map<String, dynamic> row) => row['zone'] == 2;
    expect((await store.list('parcels', where: zoneTwo)).single['id'], 'b');
    expect(
      (await store.watchTable('parcels', where: zoneTwo).first).single['id'],
      'b',
    );
  });

  test('watchTable emits again after a save', () async {
    final emissions = <int>[];
    final sub = store
        .watchTable('parcels')
        .listen((rows) => emissions.add(rows.length));

    await pumpEventQueue();
    await store.save(
      table: 'parcels',
      id: 'x',
      row: {'n': 1},
      op: SyncOp.upsert,
    );
    await pumpEventQueue();
    await sub.cancel();

    expect(emissions, containsAllInOrder([0, 1]));
  });

  group('replaceTable', () {
    test('replaces non-pending rows with the server set', () async {
      String idOf(Map<String, dynamic> r) => '${r['a']}|${r['b']}';
      await store.replaceTable('user_zones', [
        {'a': 1, 'b': 1},
        {'a': 1, 'b': 2},
      ], idOf: idOf);

      await store.replaceTable('user_zones', [
        {'a': 1, 'b': 2},
        {'a': 2, 'b': 3},
      ], idOf: idOf);

      expect(
        (await store.list('user_zones')).map(idOf),
        unorderedEquals(['1|2', '2|3']),
      );
    });
  });

  group('settle', () {
    test('clears pending once the outbox record was delivered', () async {
      await store.save(
        table: 'parcels',
        id: 'p',
        row: {'n': 1},
        op: SyncOp.upsert,
      );
      final record = (await outbox.pendingBatch()).single;
      await outbox.markSynced([record.id]);

      await store.settle([record]);

      expect(await store.isPending('parcels', 'p'), isFalse);
    });

    test('keeps pending while a newer change is still queued', () async {
      await store.save(
        table: 'parcels',
        id: 'p',
        row: {'n': 1},
        op: SyncOp.upsert,
      );
      await store.save(
        table: 'parcels',
        id: 'p',
        row: {'n': 2},
        op: SyncOp.upsert,
      );
      final first = (await outbox.pendingBatch()).first;
      await outbox.markSynced([first.id]);

      await store.settle([first]);

      expect(await store.isPending('parcels', 'p'), isTrue);
    });
  });

  test('cursors round-trip through app settings', () async {
    expect(await store.readCursor('zones'), isNull);
    final at = DateTime.utc(2026, 3, 4, 5, 6, 7);

    await store.writeCursor('zones', at);

    expect(await store.readCursor('zones'), at);
  });

  test(
    'clearAll empties replica, outbox and cursors but keeps device id',
    () async {
      final device = await outbox.deviceId();
      await store.save(
        table: 'parcels',
        id: 'p',
        row: {'n': 1},
        op: SyncOp.batch,
      );
      await store.writeCursor('zones', DateTime.utc(2026));

      await store.clearAll();

      expect(await store.list('parcels'), isEmpty);
      expect(await outbox.pendingBatch(), isEmpty);
      expect(await store.readCursor('zones'), isNull);
      expect(await outbox.deviceId(), device);
    },
  );

  test(
    'migrating v1 to v2 keeps outbox rows and adds the new schema',
    () async {
      final legacy = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(_v1Outbox);
            raw.execute(_v1Settings);
            raw.execute(_v1Row);
            raw.execute('PRAGMA user_version = 1');
          },
        ),
      );
      addTearDown(legacy.close);
      final legacyOutbox = OutboxRepository(legacy);

      final kept = (await legacyOutbox.pendingBatch()).single;
      expect(kept.id, 'legacy-1');
      expect(kept.op, SyncOp.batch);
      expect(kept.status, SyncStatus.pending);
      expect(kept.payload, {'q': 1});

      final legacyStore = LocalStore(legacy, legacyOutbox);
      await legacyStore.save(
        table: 'parcels',
        id: 'p',
        row: {'n': 1},
        op: SyncOp.upsert,
      );
      expect(await legacyStore.get('parcels', 'p'), isNotNull);
    },
  );
}

const _v1Outbox = '''
CREATE TABLE outbox (
  id TEXT NOT NULL PRIMARY KEY,
  table_name TEXT NOT NULL,
  payload TEXT NOT NULL,
  sync_status TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT NULL,
  client_created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''';

const _v1Settings = '''
CREATE TABLE app_settings (
  "key" TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
)''';

const _v1Row =
    "INSERT INTO outbox (id, table_name, payload, sync_status, "
    "client_created_at, updated_at) VALUES ('legacy-1', 'harvests', "
    "'{\"q\":1}', 'pending', 1700000000, 1700000000)";
