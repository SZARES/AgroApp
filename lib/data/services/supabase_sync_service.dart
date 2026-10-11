import 'dart:io';

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

  @override
  Future<List<Map<String, dynamic>>> pullTable(
    String table, {
    DateTime? since,
    String cursorColumn = 'updated_at',
    int limit = 1000,
  }) async {
    var query = _client.from(table).select();
    if (since != null) {
      query = query.gt(cursorColumn, since.toUtc().toIso8601String());
    }
    final rows = await query.order(cursorColumn, ascending: true).limit(limit);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }

  @override
  Future<List<Map<String, dynamic>>> pullAll(String table) async {
    final rows = await _client.from(table).select();
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }

  @override
  Future<void> upsertRow(String table, Map<String, dynamic> row) async {
    await _client.from(table).upsert(row);
  }

  @override
  Future<void> updateRow(
    String table,
    String id,
    Map<String, dynamic> changes,
  ) async {
    final updated = await _client
        .from(table)
        .update(changes)
        .eq('id', id)
        .select('id');
    if (updated.isEmpty) {
      throw StateError(
        'No row updated in $table (id $id): not visible or missing',
      );
    }
  }

  @override
  Future<void> uploadFile({
    required String bucket,
    required String path,
    required String localPath,
  }) async {
    await _client.storage
        .from(bucket)
        .upload(
          path,
          File(localPath),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
  }

  @override
  Future<String> signedUrl(String bucket, String path) {
    return _client.storage.from(bucket).createSignedUrl(path, 3600);
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
