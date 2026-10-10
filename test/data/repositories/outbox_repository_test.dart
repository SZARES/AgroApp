import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/data/local/app_database.dart';
import 'package:hackathon/data/repositories/outbox_repository.dart';
import 'package:hackathon/domain/models/sync_status.dart';
import 'package:hackathon/domain/models/sync_summary.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late AppDatabase database;
  late OutboxRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = OutboxRepository(database);
  });

  tearDown(() => database.close());

  test('enqueue stores a pending record with a generated UUID', () async {
    final record = await repository.enqueue(
      tableName: 'activities',
      payload: {'activity_type': 'irrigation', 'quantity': 2.5},
    );

    expect(record.id, matches(_uuidV4));
    expect(record.status, SyncStatus.pending);
    expect(record.attempts, 0);

    final stored = (await repository.pendingBatch()).single;
    expect(stored.id, record.id);
    expect(stored.tableName, 'activities');
    expect(stored.payload, {'activity_type': 'irrigation', 'quantity': 2.5});
    expect(stored.status, SyncStatus.pending);
    expect(stored.lastError, isNull);
  });

  test('enqueue keeps a caller-provided id', () async {
    const id = '3f2b8c1e-5d47-4a9b-8e21-0c6d7f9a1b23';

    final record = await repository.enqueue(
      tableName: 'harvests',
      payload: const {},
      id: id,
    );

    expect(record.id, id);
  });

  test('pendingBatch returns retryable records up to the limit', () async {
    final first = await repository.enqueue(tableName: 'a', payload: const {});
    final second = await repository.enqueue(tableName: 'a', payload: const {});
    final third = await repository.enqueue(tableName: 'a', payload: const {});
    final fourth = await repository.enqueue(tableName: 'a', payload: const {});
    await repository.markSynced([first.id]);
    await repository.markSyncing([second.id]);
    await repository.markFailed(third.id, 'rejected');

    final batch = await repository.pendingBatch();
    expect(batch.map((r) => r.id), unorderedEquals([third.id, fourth.id]));
    expect(await repository.pendingBatch(limit: 1), hasLength(1));
  });

  test('markFailed stores the error and increments attempts', () async {
    final record = await repository.enqueue(tableName: 'a', payload: const {});

    await repository.markFailed(record.id, 'first');
    await repository.markFailed(record.id, 'second');

    final stored = (await repository.pendingBatch()).single;
    expect(stored.status, SyncStatus.error);
    expect(stored.attempts, 2);
    expect(stored.lastError, 'second');
  });

  test('requeueInterrupted returns syncing records to pending', () async {
    final record = await repository.enqueue(tableName: 'a', payload: const {});
    await repository.markSyncing([record.id]);
    expect(await repository.pendingBatch(), isEmpty);

    await repository.requeueInterrupted();

    final stored = (await repository.pendingBatch()).single;
    expect(stored.status, SyncStatus.pending);
  });

  test('watchSummary counts unsent records by state', () async {
    final failed = await repository.enqueue(tableName: 'a', payload: const {});
    final synced = await repository.enqueue(tableName: 'a', payload: const {});
    final syncing = await repository.enqueue(tableName: 'a', payload: const {});
    await repository.enqueue(tableName: 'a', payload: const {});
    await repository.markFailed(failed.id, 'rejected');
    await repository.markSynced([synced.id]);
    await repository.markSyncing([syncing.id]);

    expect(
      await repository.watchSummary().first,
      const SyncSummary(pending: 2, error: 1),
    );
  });

  test('watchSummary reports an empty outbox as all synced', () async {
    final summary = await repository.watchSummary().first;

    expect(summary, const SyncSummary());
    expect(summary.isAllSynced, isTrue);
  });

  test('deviceId is generated once and stays stable', () async {
    final first = await repository.deviceId();
    final second = await repository.deviceId();
    final fromNewRepository = await OutboxRepository(database).deviceId();

    expect(first, matches(_uuidV4));
    expect(second, first);
    expect(fromNewRepository, first);
  });
}
