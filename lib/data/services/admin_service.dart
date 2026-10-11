typedef AdminRow = Map<String, dynamic>;

/// A failed admin request, in transport-neutral terms.
class AdminServiceException implements Exception {
  const AdminServiceException({
    this.statusCode,
    this.code,
    this.message,
    this.isNetwork = false,
  });

  /// HTTP status of an Edge Function answer, when there was one.
  final int? statusCode;

  /// Postgres/PostgREST error code (for example `23505`), when there was one.
  final String? code;
  final String? message;

  /// The request never reached the server.
  final bool isNetwork;

  @override
  String toString() =>
      'AdminServiceException($statusCode, $code, $message, network=$isNetwork)';
}

/// Online-only administration calls. Every method throws
/// [AdminServiceException] on failure.
abstract interface class AdminService {
  /// Id of the signed-in admin (`auth.uid()`).
  String? get currentUserId;

  /// Edge Function `admin-create-user`; returns its JSON answer.
  Future<AdminRow> createUser(Map<String, dynamic> body);

  /// Edge Function `admin-manage-user` (reset_password / set_status).
  Future<void> manageUser(Map<String, dynamic> body);

  /// Inserts one row and returns it as stored.
  Future<AdminRow> insertRow(String table, AdminRow row);

  /// Updates one row by [idColumn] and returns it as stored.
  Future<AdminRow> updateRow(
    String table,
    String idColumn,
    String id,
    AdminRow changes,
  );

  /// Insert or update on [onConflict]; returns the stored row.
  Future<AdminRow> upsertRow(
    String table,
    AdminRow row, {
    required String onConflict,
  });

  /// Deletes join rows whose columns equal [match].
  Future<void> deleteJoinRows(String table, Map<String, String> match);

  Future<void> insertJoinRows(String table, List<AdminRow> rows);

  /// Newest first. Only admins can read `audit_logs`.
  Future<List<AdminRow>> fetchAuditLogs({
    int limit = 100,
    String? table,
    String? actorId,
    DateTime? from,
    DateTime? to,
  });
}
