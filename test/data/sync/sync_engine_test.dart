import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/data/services/sync_service.dart';
import 'package:hackathon/data/sync/sync_engine.dart';
import 'package:hackathon/domain/models/sync_status.dart';
import 'package:hackathon/utils/result.dart';

import '../../testing/fakes.dart';

void main() {
  late AppDatabase database;
  late OutboxRepository repository;
  late LocalStore localStore;
  late FakeSyncService syncService;
  late FakeConnectivityService connectivity;
  late SyncEngine engine;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = OutboxRepository(database);
    localStore = LocalStore(database, repository);
    syncService = FakeSyncService();
    connectivity = FakeConnectivityService();
    engine = SyncEngine(
      repository: repository,
      localStore: localStore,
      syncService: syncService,
      connectivity: connectivity,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await connectivity.close();
    await database.close();
  });

  Future<Map<String, OutboxRow>> storedRows() async {
    final rows = await database.select(database.outbox).get();
    return {for (final row in rows) row.id: row};
  }

  Future<void> waitUntilRemoved(String id) {
    final query = database.select(database.outbox)
      ..where((row) => row.id.equals(id));
    return query.watch().firstWhere((rows) => rows.isEmpty);
  }

  test('does nothing while offline', () async {
    connectivity.online = false;
    final record = await repository.enqueue(tableName: 'a', payload: const {});

    final result = await engine.syncPending();

    expect(result, isA<Ok<SyncReport>>());
    expect(syncService.batches, isEmpty);
    expect((await storedRows())[record.id]!.syncStatus, SyncStatus.pending);
  });

  test('skips the request when nothing is pending', () async {
    final result = await engine.syncPending();

    expect(result, isA<Ok<SyncReport>>());
    expect(syncService.batches, isEmpty);
  });

  test('sends the batch with the persisted device id', () async {
    final record = await repository.enqueue(
      tableName: 'harvests',
      payload: {'quantity': 3},
    );

    await engine.syncPending();

    expect(syncService.deviceIds, [await repository.deviceId()]);
    final sent = syncService.batches.single.single;
    expect(sent.id, record.id);
    expect(sent.tableName, 'harvests');
    expect(sent.payload, {'quantity': 3});
  });

  test('applies a partial result without aborting the batch', () async {
    final accepted = await repository.enqueue(
      tableName: 'a',
      payload: const {},
    );
    final rejected = await repository.enqueue(
      tableName: 'a',
      payload: const {},
    );
    syncService.handler = (_) => SyncBatchResult(
      syncedIds: [accepted.id],
      failures: [SyncFailure(id: rejected.id, error: 'Tabla no permitida: a')],
    );

    final result = await engine.syncPending();

    final report = (result as Ok<SyncReport>).value;
    expect(report.synced, 1);
    expect(report.failed, 1);
    final rows = await storedRows();
    expect(rows.containsKey(accepted.id), isFalse);
    expect(rows[rejected.id]!.syncStatus, SyncStatus.error);
    expect(rows[rejected.id]!.attempts, 1);
    expect(rows[rejected.id]!.lastError, 'Tabla no permitida: a');
  });

  test('keeps every record retryable when the request throws', () async {
    final first = await repository.enqueue(tableName: 'a', payload: const {});
    final second = await repository.enqueue(tableName: 'a', payload: const {});
    syncService.handler = (_) =>
        throw const SocketException('Connection reset');

    final result = await engine.syncPending();

    expect(result, isA<Error<SyncReport>>());
    final rows = await storedRows();
    for (final id in [first.id, second.id]) {
      expect(rows[id]!.syncStatus, SyncStatus.error);
      expect(rows[id]!.attempts, 1);
      expect(rows[id]!.lastError, contains('Connection reset'));
    }
    expect(
      (await repository.pendingBatch()).map((r) => r.id),
      unorderedEquals([first.id, second.id]),
    );
  });

  test('retries failed records on the next run', () async {
    final record = await repository.enqueue(tableName: 'a', payload: const {});
    syncService.handler = (_) => throw const SocketException('offline');
    await engine.syncPending();
    syncService.handler = null;

    await engine.syncPending();

    expect((await storedRows()).containsKey(record.id), isFalse);
  });

  test('marks records missing from the response as failed', () async {
    final record = await repository.enqueue(tableName: 'a', payload: const {});
    syncService.handler = (_) =>
        const SyncBatchResult(syncedIds: [], failures: []);

    await engine.syncPending();

    final row = (await storedRows())[record.id]!;
    expect(row.syncStatus, SyncStatus.error);
    expect(row.attempts, 1);
  });

  test('does not start a second run while one is in flight', () async {
    await repository.enqueue(tableName: 'a', payload: const {});
    final release = Completer<void>();
    syncService.handler = (records) async {
      await release.future;
      return SyncBatchResult(
        syncedIds: [for (final record in records) record.id],
        failures: const [],
      );
    };

    final running = engine.syncPending();
    final overlapping = await engine.syncPending();
    release.complete();
    await running;

    expect(overlapping, isA<Ok<SyncReport>>());
    expect(syncService.batches, hasLength(1));
  });

  test('start syncs when connectivity returns', () async {
    connectivity.online = false;
    final record = await repository.enqueue(tableName: 'a', payload: const {});
    await engine.start();
    expect(syncService.batches, isEmpty);

    connectivity.setOnline(true);
    await waitUntilRemoved(record.id);

    expect(syncService.batches, hasLength(1));
  });

  test('start recovers records interrupted in a previous session', () async {
    connectivity.online = false;
    final record = await repository.enqueue(tableName: 'a', payload: const {});
    await repository.markSyncing([record.id]);

    await engine.start();

    expect((await storedRows())[record.id]!.syncStatus, SyncStatus.pending);
  });
}
