import 'dart:async';

import 'package:hackathon/data/repositories/admin_repository.dart';
import 'package:hackathon/data/repositories/local_store.dart';
import 'package:hackathon/data/services/admin_service.dart';
import 'package:hackathon/domain/models/admin/admin_user.dart';
import 'package:hackathon/domain/models/admin/audit_log_entry.dart';
import 'package:hackathon/domain/models/admin/catalog_def.dart';
import 'package:hackathon/domain/models/admin/create_user_request.dart';
import 'package:hackathon/domain/models/app_user.dart';
import 'package:hackathon/utils/result.dart';

/// Records every call; set [failWith] to make the next calls throw.
class FakeAdminService implements AdminService {
  @override
  String? currentUserId = 'admin-1';

  AdminServiceException? failWith;

  final List<Map<String, dynamic>> createdBodies = [];
  final List<Map<String, dynamic>> manageBodies = [];
  final List<({String table, AdminRow row})> inserts = [];
  final List<({String table, String idColumn, String id, AdminRow changes})>
  updates = [];
  final List<({String table, AdminRow row, String onConflict})> upserts = [];
  final List<({String table, Map<String, String> match})> joinDeletes = [];
  final List<({String table, List<AdminRow> rows})> joinInserts = [];
  List<AdminRow> auditRows = [];

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<AdminRow> createUser(Map<String, dynamic> body) async {
    _maybeFail();
    createdBodies.add(body);
    return {'ok': true, 'user_id': 'new-user', 'farmer_id': 'new-farmer'};
  }

  @override
  Future<void> manageUser(Map<String, dynamic> body) async {
    _maybeFail();
    manageBodies.add(body);
  }

  @override
  Future<AdminRow> insertRow(String table, AdminRow row) async {
    _maybeFail();
    inserts.add((table: table, row: row));
    return {...row, 'updated_at': '2026-01-01T00:00:00Z'};
  }

  @override
  Future<AdminRow> updateRow(
    String table,
    String idColumn,
    String id,
    AdminRow changes,
  ) async {
    _maybeFail();
    updates.add((table: table, idColumn: idColumn, id: id, changes: changes));
    return {idColumn: id, ...changes, 'updated_at': '2026-01-02T00:00:00Z'};
  }

  @override
  Future<AdminRow> upsertRow(
    String table,
    AdminRow row, {
    required String onConflict,
  }) async {
    _maybeFail();
    upserts.add((table: table, row: row, onConflict: onConflict));
    return {...row, 'updated_at': '2026-01-02T00:00:00Z'};
  }

  @override
  Future<void> deleteJoinRows(String table, Map<String, String> match) async {
    _maybeFail();
    joinDeletes.add((table: table, match: match));
  }

  @override
  Future<void> insertJoinRows(String table, List<AdminRow> rows) async {
    _maybeFail();
    joinInserts.add((table: table, rows: rows));
  }

  @override
  Future<List<AdminRow>> fetchAuditLogs({
    int limit = 100,
    String? table,
    String? actorId,
    DateTime? from,
    DateTime? to,
  }) async {
    _maybeFail();
    return auditRows;
  }
}

/// In-memory [AdminRepository] for view-model tests.
class FakeAdminRepository implements AdminRepository {
  @override
  String? currentUserId = 'admin-1';

  final usersController = StreamController<List<AdminUser>>.broadcast();
  final Map<String, List<JsonMap>> tables = {};
  final Map<String, StreamController<List<JsonMap>>> _controllers = {};

  /// Result returned by [createUser]; defaults to a farmer account.
  Result<CreatedUser>? createResult;
  final List<CreateUserRequest> createRequests = [];
  final List<({String id, String password})> passwordResets = [];
  final List<({String id, UserStatus status})> statusChanges = [];
  final List<({CatalogDef def, JsonMap row})> savedRows = [];
  final List<({AllowedUnitsJoin join, String owner, List<String> units})>
  unitSets = [];
  List<AuditLogEntry> audit = [];

  @override
  Stream<List<AdminUser>> watchUsers() => usersController.stream;

  @override
  Stream<List<JsonMap>> watchRows(String table) {
    final controller = _controllers.putIfAbsent(
      table,
      () => StreamController<List<JsonMap>>.broadcast(onListen: () {}),
    );
    // Emit the current rows right after subscription.
    return Stream.multi((multi) {
      multi.add(tables[table] ?? const []);
      final sub = controller.stream.listen(multi.add);
      multi.onCancel = sub.cancel;
    });
  }

  void emitRows(String table, List<JsonMap> rows) {
    tables[table] = rows;
    _controllers[table]?.add(rows);
  }

  @override
  Future<Result<CreatedUser>> createUser(CreateUserRequest request) async {
    createRequests.add(request);
    return createResult ??
        Result.ok(
          CreatedUser(
            userId: 'new-user',
            role: request.role,
            loginIdentifier: request.isFarmer ? request.dni : request.email,
            isDni: request.isFarmer,
          ),
        );
  }

  @override
  Future<Result<void>> resetPassword(String userId, String password) async {
    passwordResets.add((id: userId, password: password));
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setUserStatus(String userId, UserStatus status) async {
    statusChanges.add((id: userId, status: status));
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> updateProfile(
    String userId, {
    required String fullName,
    String? phone,
  }) async => const Result.ok(null);

  @override
  Future<Result<void>> setUserZones(
    String userId,
    List<String> zoneIds,
  ) async => const Result.ok(null);

  @override
  Future<Result<void>> setTechnicianParcels(
    String technicianId,
    List<String> parcelIds,
  ) async => const Result.ok(null);

  @override
  Future<Result<JsonMap>> saveCatalogRow(CatalogDef def, JsonMap row) async {
    savedRows.add((def: def, row: row));
    return Result.ok({'id': 'saved-id', ...row});
  }

  @override
  Future<Result<void>> setActive(
    CatalogDef def,
    String id,
    bool active,
  ) async => const Result.ok(null);

  @override
  Future<Result<void>> setAllowedUnits(
    AllowedUnitsJoin join,
    String ownerId,
    List<String> unitIds,
  ) async {
    unitSets.add((join: join, owner: ownerId, units: unitIds));
    return const Result.ok(null);
  }

  @override
  Future<Result<JsonMap>> saveSetting(
    String key,
    Object? jsonValue, {
    String? description,
  }) async => Result.ok({'key': key, 'value': jsonValue});

  @override
  Future<Result<List<AuditLogEntry>>> fetchAuditLogs({
    int limit = 100,
    String? table,
    String? actorId,
    DateTime? from,
    DateTime? to,
  }) async => Result.ok(audit);
}
