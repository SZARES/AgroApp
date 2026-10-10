import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/outbox_record.dart';
import 'sync_service.dart';

class SupabaseSyncService implements SyncService {
  const SupabaseSyncService(this._client);

  final SupabaseClient _client;

  @override
  Future<SyncBatchResult> syncBatch({
    required String deviceId,
    required List<OutboxRecord> records,
  }) async {
    final response = await _client.rpc<dynamic>(
      'sync_batch',
      params: {
        'p_device_id': deviceId,
        'p_records': [
          for (final record in records)
            {
              'table': record.tableName,
              'id': record.id,
              'payload': record.payload,
              'client_created_at': record.clientCreatedAt
                  .toUtc()
                  .toIso8601String(),
            },
        ],
      },
    );
    return _parse(response);
  }

  SyncBatchResult _parse(Object? response) {
    if (response is! Map) {
      throw const FormatException('Unexpected sync_batch response');
    }
    final synced = response['synced'] as List? ?? const [];
    final failed = response['failed'] as List? ?? const [];
    return SyncBatchResult(
      syncedIds: [for (final id in synced) id.toString()],
      failures: [
        for (final entry in failed.whereType<Map<dynamic, dynamic>>())
          if (entry['id'] != null)
            SyncFailure(
              id: entry['id'].toString(),
              error: entry['error']?.toString() ?? 'Unknown error',
            ),
      ],
    );
  }
}
