import '../../domain/models/outbox_record.dart';

class SyncFailure {
  const SyncFailure({required this.id, required this.error});

  final String id;
  final String error;
}

class SyncBatchResult {
  const SyncBatchResult({required this.syncedIds, required this.failures});

  final List<String> syncedIds;
  final List<SyncFailure> failures;
}

abstract interface class SyncService {
  /// Uploads [records] in one request. A rejected record is reported in
  /// [SyncBatchResult.failures]; only transport-level problems throw.
  Future<SyncBatchResult> syncBatch({
    required String deviceId,
    required List<OutboxRecord> records,
  });
}
