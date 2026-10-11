import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_service.dart';

/// Supabase implementation of [AdminService] (PostgREST + Edge Functions).
class SupabaseAdminService implements AdminService {
  const SupabaseAdminService(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<AdminRow> createUser(Map<String, dynamic> body) =>
      _invoke('admin-create-user', body);

  @override
  Future<void> manageUser(Map<String, dynamic> body) async {
    await _invoke('admin-manage-user', body);
  }

  @override
  Future<AdminRow> insertRow(String table, AdminRow row) => _guard(() async {
    final stored = await _client.from(table).insert(row).select().single();
    return Map<String, dynamic>.from(stored);
  });

  @override
  Future<AdminRow> updateRow(
    String table,
    String idColumn,
    String id,
    AdminRow changes,
  ) => _guard(() async {
    final stored = await _client
        .from(table)
        .update(changes)
        .eq(idColumn, id)
        .select()
        .maybeSingle();
    if (stored == null) {
      throw const AdminServiceException(code: 'PGRST116', message: 'not found');
    }
    return Map<String, dynamic>.from(stored);
  });

  @override
  Future<AdminRow> upsertRow(
    String table,
    AdminRow row, {
    required String onConflict,
  }) => _guard(() async {
    final stored = await _client
        .from(table)
        .upsert(row, onConflict: onConflict)
        .select()
        .single();
    return Map<String, dynamic>.from(stored);
  });

  @override
  Future<void> deleteJoinRows(String table, Map<String, String> match) =>
      _guard(() async {
        await _client.from(table).delete().match(match);
      });

  @override
  Future<void> insertJoinRows(String table, List<AdminRow> rows) =>
      _guard(() async {
        if (rows.isEmpty) return;
        await _client.from(table).insert(rows);
      });

  @override
  Future<List<AdminRow>> fetchAuditLogs({
    int limit = 100,
    String? table,
    String? actorId,
    DateTime? from,
    DateTime? to,
  }) => _guard(() async {
    var query = _client.from('audit_logs').select();
    if (table != null) query = query.eq('table_name', table);
    if (actorId != null) query = query.eq('actor_id', actorId);
    if (from != null) {
      query = query.gte('created_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lt('created_at', to.toUtc().toIso8601String());
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  });

  Future<AdminRow> _invoke(String function, Map<String, dynamic> body) =>
      _guard(() async {
        final response = await _client.functions.invoke(function, body: body);
        final data = response.data;
        return data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AdminServiceException {
      rethrow;
    } on FunctionException catch (error) {
      final details = error.details;
      throw AdminServiceException(
        statusCode: error.status,
        message: details is Map ? details['error']?.toString() : null,
      );
    } on PostgrestException catch (error) {
      throw AdminServiceException(code: error.code, message: error.message);
    } on AuthException catch (error) {
      if (error is AuthRetryableFetchException) {
        throw AdminServiceException(message: error.message, isNetwork: true);
      }
      throw AdminServiceException(
        statusCode: int.tryParse(error.statusCode ?? ''),
        message: error.message,
      );
    } catch (error) {
      // Socket, HTTP client and timeout errors: the server was not reached.
      throw AdminServiceException(message: '$error', isNetwork: true);
    }
  }
}
