import 'dart:async';

import '../../domain/models/admin/admin_failure.dart';
import '../../domain/models/admin/admin_user.dart';
import '../../domain/models/admin/audit_log_entry.dart';
import '../../domain/models/admin/catalog_def.dart';
import '../../domain/models/admin/create_user_request.dart';
import '../../domain/models/app_user.dart';
import '../../domain/models/user_role.dart';
import '../../utils/result.dart';
import '../services/admin_service.dart';
import '../services/connectivity_service.dart';
import '../sync/sync_tables.dart';
import 'local_store.dart';

/// Administration of users and catalogs. Writes go straight to Supabase (the
/// console is online-only for configuration) and the stored row is applied to
/// the local replica so lists update at once; reads always come from the
/// replica.
abstract interface class AdminRepository {
  /// Id of the signed-in admin.
  String? get currentUserId;

  Stream<List<AdminUser>> watchUsers();

  /// Live rows of a replicated table (soft-deleted ones excluded).
  Stream<List<JsonMap>> watchRows(String table);

  Future<Result<CreatedUser>> createUser(CreateUserRequest request);
  Future<Result<void>> resetPassword(String userId, String password);
  Future<Result<void>> setUserStatus(String userId, UserStatus status);
  Future<Result<void>> updateProfile(
    String userId, {
    required String fullName,
    String? phone,
  });

  /// Replaces the zones of [userId] with [zoneIds].
  Future<Result<void>> setUserZones(String userId, List<String> zoneIds);

  /// Replaces the parcels assigned to [technicianId].
  Future<Result<void>> setTechnicianParcels(
    String technicianId,
    List<String> parcelIds,
  );

  /// Inserts (new id) or updates (known id) one catalog row.
  Future<Result<JsonMap>> saveCatalogRow(CatalogDef def, JsonMap row);

  /// Activates or deactivates a row (never a hard delete).
  Future<Result<void>> setActive(CatalogDef def, String id, bool active);

  /// Replaces the units [ownerId] allows with [unitIds].
  Future<Result<void>> setAllowedUnits(
    AllowedUnitsJoin join,
    String ownerId,
    List<String> unitIds,
  );

  Future<Result<JsonMap>> saveSetting(
    String key,
    Object? jsonValue, {
    String? description,
  });

  Future<Result<List<AuditLogEntry>>> fetchAuditLogs({
    int limit = 100,
    String? table,
    String? actorId,
    DateTime? from,
    DateTime? to,
  });
}

class DefaultAdminRepository implements AdminRepository {
  DefaultAdminRepository({
    required AdminService service,
    required LocalStore store,
    required ConnectivityService connectivity,
    Future<void> Function()? requestSync,
    DateTime Function()? clock,
  }) : _service = service,
       _store = store,
       _connectivity = connectivity,
       _requestSync = requestSync,
       _clock = clock ?? DateTime.now;

  final AdminService _service;
  final LocalStore _store;
  final ConnectivityService _connectivity;
  final Future<void> Function()? _requestSync;
  final DateTime Function() _clock;

  @override
  String? get currentUserId => _service.currentUserId;

  // ---- Reads (replica) ----

  @override
  Stream<List<JsonMap>> watchRows(String table) => _store.watchTable(table);

  @override
  Stream<List<AdminUser>> watchUsers() {
    const tables = [
      'profiles',
      'farmers',
      'user_zones',
      'communities',
      'zones',
    ];
    late StreamController<List<AdminUser>> controller;
    final subscriptions = <StreamSubscription<Object?>>[];
    var scheduled = false;

    Future<void> rebuild() async {
      scheduled = false;
      if (controller.isClosed) return;
      controller.add(await _buildUsers());
    }

    void onChange(Object? _) {
      if (scheduled) return;
      scheduled = true;
      scheduleMicrotask(rebuild);
    }

    controller = StreamController<List<AdminUser>>(
      onListen: () {
        for (final table in tables) {
          subscriptions.add(_store.watchTable(table).listen(onChange));
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  Future<List<AdminUser>> _buildUsers() async {
    final profiles = await _store.list('profiles');
    final farmers = await _store.list('farmers');
    final userZones = await _store.list('user_zones');
    final communities = {
      for (final row in await _store.list('communities'))
        '${row['id']}': '${row['name']}',
    };
    final zones = {
      for (final row in await _store.list('zones'))
        '${row['id']}': '${row['name']}',
    };
    final farmerByUser = {for (final f in farmers) '${f['user_id']}': f};
    final zonesByUser = <String, List<String>>{};
    for (final row in userZones) {
      (zonesByUser['${row['user_id']}'] ??= []).add('${row['zone_id']}');
    }

    final users = <AdminUser>[];
    for (final profile in profiles) {
      final role = UserRole.values.asNameMap()['${profile['role']}'];
      if (role == null) continue;
      final id = '${profile['id']}';
      final farmer = farmerByUser[id];
      final zoneIds = zonesByUser[id] ?? const <String>[];
      final communityId = farmer?['community_id'] as String?;
      users.add(
        AdminUser(
          id: id,
          fullName: (profile['full_name'] as String?) ?? '',
          email: (profile['email'] as String?) ?? '',
          role: role,
          status:
              UserStatus.values.asNameMap()['${profile['status']}'] ??
              UserStatus.inactive,
          phone: (profile['phone'] as String?) ?? farmer?['phone'] as String?,
          farmerId: farmer?['id'] as String?,
          dni: farmer?['dni'] as String?,
          communityId: communityId,
          communityName: communityId == null ? null : communities[communityId],
          ageRange: farmer?['age_range'] as String?,
          lastActivityAt: DateTime.tryParse(
            '${farmer?['last_activity_at'] ?? ''}',
          ),
          zoneIds: zoneIds,
          zoneNames: [for (final z in zoneIds) ?zones[z]],
        ),
      );
    }
    users.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return users;
  }

  // ---- Users ----

  @override
  Future<Result<CreatedUser>> createUser(CreateUserRequest request) {
    return _write(() async {
      final response = await _service.createUser(request.toJson());
      final userId = response['user_id'];
      if (userId is! String) {
        throw const AdminServiceException(message: 'Respuesta inesperada');
      }
      final requestSync = _requestSync;
      if (requestSync != null) {
        // Best effort: the sync poll would pick the new rows up anyway.
        unawaited(requestSync().catchError((Object _) {}));
      }
      return CreatedUser(
        userId: userId,
        role: request.role,
        farmerId: response['farmer_id'] as String?,
        loginIdentifier: request.isFarmer
            ? request.dni.trim()
            : request.email.trim().toLowerCase(),
        isDni: request.isFarmer,
      );
    });
  }

  @override
  Future<Result<void>> resetPassword(String userId, String password) {
    return _write(
      () => _service.manageUser({
        'user_id': userId,
        'action': 'reset_password',
        'password': password,
      }),
    );
  }

  @override
  Future<Result<void>> setUserStatus(String userId, UserStatus status) {
    return _write(() async {
      await _service.manageUser({
        'user_id': userId,
        'action': 'set_status',
        'status': status.name,
      });
      final existing = await _store.get('profiles', userId);
      if (existing != null) {
        await _store.applyServerRows('profiles', [
          {...existing, 'status': status.name},
        ]);
      }
    });
  }

  @override
  Future<Result<void>> updateProfile(
    String userId, {
    required String fullName,
    String? phone,
  }) {
    return _write(() async {
      final changes = {
        'full_name': fullName.trim(),
        'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      };
      final stored = await _service.updateRow(
        'profiles',
        'id',
        userId,
        changes,
      );
      await _apply('profiles', stored);
      final farmers = await _store.list(
        'farmers',
        where: (row) => row['user_id'] == userId,
      );
      for (final farmer in farmers) {
        final storedFarmer = await _service.updateRow(
          'farmers',
          'id',
          '${farmer['id']}',
          {'phone': changes['phone']},
        );
        await _apply('farmers', storedFarmer);
      }
    });
  }

  @override
  Future<Result<void>> setUserZones(String userId, List<String> zoneIds) {
    return _write(
      () => _replaceJoin(
        table: 'user_zones',
        ownerColumn: 'user_id',
        ownerId: userId,
        otherColumn: 'zone_id',
        otherIds: zoneIds,
      ),
    );
  }

  @override
  Future<Result<void>> setTechnicianParcels(
    String technicianId,
    List<String> parcelIds,
  ) {
    return _write(
      () => _replaceJoin(
        table: 'technician_parcels',
        ownerColumn: 'technician_id',
        ownerId: technicianId,
        otherColumn: 'parcel_id',
        otherIds: parcelIds,
      ),
    );
  }

  // ---- Catalogs ----

  @override
  Future<Result<JsonMap>> saveCatalogRow(CatalogDef def, JsonMap row) {
    return _write(() async {
      final id = row[def.idColumn] as String?;
      final existing = id == null ? null : await _store.get(def.table, id);
      final data = {...row};
      if (def.stampsValidation && data.containsKey('validated')) {
        final becomesValid = data['validated'] == true;
        final wasValid = existing?['validated'] == true;
        if (becomesValid && !wasValid) {
          data['validated_by'] = _service.currentUserId;
          data['validated_at'] = _clock().toUtc().toIso8601String();
        } else if (!becomesValid) {
          data['validated_by'] = null;
          data['validated_at'] = null;
        }
      }

      final JsonMap stored;
      if (def.usesKeyAsId) {
        stored = await _service.upsertRow(
          def.table,
          data,
          onConflict: def.idColumn,
        );
      } else if (existing != null) {
        data.remove('id');
        stored = await _service.updateRow(def.table, 'id', id!, data);
      } else {
        data['id'] ??= _store.newId();
        stored = await _service.insertRow(def.table, data);
      }
      await _apply(def.table, stored);
      return stored;
    });
  }

  @override
  Future<Result<void>> setActive(CatalogDef def, String id, bool active) {
    return _write(() async {
      final changes = def.hasActive
          ? {'active': active}
          : {'deleted_at': active ? null : _clock().toUtc().toIso8601String()};
      final stored = await _service.updateRow(
        def.table,
        def.idColumn,
        id,
        changes,
      );
      await _apply(def.table, stored);
    });
  }

  @override
  Future<Result<void>> setAllowedUnits(
    AllowedUnitsJoin join,
    String ownerId,
    List<String> unitIds,
  ) {
    return _write(
      () => _replaceJoin(
        table: join.table,
        ownerColumn: join.ownerColumn,
        ownerId: ownerId,
        otherColumn: join.unitColumn,
        otherIds: unitIds,
      ),
    );
  }

  @override
  Future<Result<JsonMap>> saveSetting(
    String key,
    Object? jsonValue, {
    String? description,
  }) {
    return saveCatalogRow(_settingsDef, {
      'key': key,
      'value': jsonValue,
      'description': (description == null || description.trim().isEmpty)
          ? null
          : description.trim(),
    });
  }

  static const _settingsDef = CatalogDef(
    id: 'app_settings',
    table: 'app_settings',
    title: 'Configuración',
    singular: 'configuración',
    idColumn: 'key',
    fields: [],
    hasActive: false,
    hasSortOrder: false,
  );

  // ---- Audit ----

  @override
  Future<Result<List<AuditLogEntry>>> fetchAuditLogs({
    int limit = 100,
    String? table,
    String? actorId,
    DateTime? from,
    DateTime? to,
  }) {
    return _write(() async {
      final rows = await _service.fetchAuditLogs(
        limit: limit,
        table: table,
        actorId: actorId,
        from: from,
        to: to,
      );
      return [for (final row in rows) ?AuditLogEntry.tryFromRow(row)];
    });
  }

  // ---- Helpers ----

  /// Runs [action] online and maps every failure to [AdminFailureException].
  Future<Result<T>> _write<T>(Future<T> Function() action) async {
    if (!await _connectivity.isOnline()) {
      return Result.error(const AdminFailureException(AdminFailure.offline));
    }
    try {
      return Result.ok(await action());
    } on AdminServiceException catch (error) {
      return Result.error(_map(error));
    } on AdminFailureException catch (error) {
      return Result.error(error);
    } catch (error) {
      return Result.error(
        AdminFailureException(AdminFailure.unknown, null, error),
      );
    }
  }

  AdminFailureException _map(AdminServiceException error) {
    if (error.isNetwork) {
      return AdminFailureException(AdminFailure.offline, null, error);
    }
    final status = error.statusCode;
    final code = error.code;
    if (status == 401 || status == 403 || code == '42501') {
      return AdminFailureException(AdminFailure.forbidden, null, error);
    }
    if (code == '23505' || status == 409) {
      return AdminFailureException(AdminFailure.duplicate, null, error);
    }
    if (code == 'PGRST116' || status == 404) {
      return AdminFailureException(AdminFailure.notFound, null, error);
    }
    if (status == 400) {
      // Edge Functions answer 400 with a Spanish explanation.
      return AdminFailureException(AdminFailure.invalid, error.message, error);
    }
    if (code == '23503' ||
        code == '23502' ||
        code == '22P02' ||
        code == '23514') {
      return AdminFailureException(AdminFailure.invalid, null, error);
    }
    return AdminFailureException(AdminFailure.unknown, null, error);
  }

  Future<void> _apply(String table, JsonMap stored) {
    return _store.applyServerRows(table, [
      stored,
    ], idOf: (row) => _rowId(table, row));
  }

  String _rowId(String table, JsonMap row) {
    for (final candidate in SyncTables.pullTables) {
      if (candidate.name == table) return candidate.rowId(row);
    }
    return '${row['id']}';
  }

  Future<void> _replaceJoin({
    required String table,
    required String ownerColumn,
    required String ownerId,
    required String otherColumn,
    required List<String> otherIds,
  }) async {
    final current = {
      for (final row in await _store.list(
        table,
        where: (row) => row[ownerColumn] == ownerId,
      ))
        '${row[otherColumn]}',
    };
    final wanted = otherIds.toSet();
    final removed = current.difference(wanted);
    final added = wanted.difference(current);

    for (final other in removed) {
      await _service.deleteJoinRows(table, {
        ownerColumn: ownerId,
        otherColumn: other,
      });
    }
    final rows = [
      for (final other in added) {ownerColumn: ownerId, otherColumn: other},
    ];
    await _service.insertJoinRows(table, rows);

    await _store.removeRows(table, [
      for (final other in removed)
        _rowId(table, {ownerColumn: ownerId, otherColumn: other}),
    ]);
    await _store.applyServerRows(
      table,
      rows,
      idOf: (row) => _rowId(table, row),
    );
  }
}
