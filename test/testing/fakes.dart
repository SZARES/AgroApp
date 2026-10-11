import 'dart:async';

import 'package:hackathon/data/repositories/auth_repository.dart';
import 'package:hackathon/data/services/auth_service.dart';
import 'package:hackathon/data/services/connectivity_service.dart';
import 'package:hackathon/data/services/sync_service.dart';
import 'package:hackathon/domain/models/app_user.dart';
import 'package:hackathon/domain/models/auth_failure.dart';
import 'package:hackathon/domain/models/outbox_record.dart';
import 'package:hackathon/utils/result.dart';

typedef SyncHandler =
    FutureOr<SyncBatchResult> Function(List<OutboxRecord> records);

class FakeSyncService implements SyncService {
  FakeSyncService([this.handler]);

  /// Defaults to accepting every record.
  SyncHandler? handler;

  final List<List<OutboxRecord>> batches = [];
  final List<String> deviceIds = [];

  /// Rows returned by [pullTable]/[pullAll], per table. Pages are served by
  /// filtering on the cursor column like the real backend does.
  final Map<String, List<Map<String, dynamic>>> serverRows = {};
  final List<({String table, DateTime? since, int limit})> pulls = [];
  final List<String> pullAlls = [];
  final List<({String table, Map<String, dynamic> row})> upserts = [];
  final List<({String table, String id, Map<String, dynamic> changes})>
  updates = [];

  /// Tables whose pull throws.
  final Set<String> failingPulls = {};

  /// Row ids whose upsert/update throws.
  final Set<String> failingRows = {};

  @override
  Future<SyncBatchResult> syncBatch({
    required String deviceId,
    required List<OutboxRecord> records,
  }) async {
    deviceIds.add(deviceId);
    batches.add(records);
    final handler = this.handler;
    if (handler != null) return handler(records);
    return SyncBatchResult(
      syncedIds: [for (final record in records) record.id],
      failures: const [],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> pullTable(
    String table, {
    DateTime? since,
    String cursorColumn = 'updated_at',
    int limit = 1000,
  }) async {
    pulls.add((table: table, since: since, limit: limit));
    if (failingPulls.contains(table)) throw Exception('pull failed: $table');
    final rows = [...?serverRows[table]]
      ..sort(
        (a, b) => DateTime.parse(
          a[cursorColumn] as String,
        ).compareTo(DateTime.parse(b[cursorColumn] as String)),
      );
    return rows
        .where(
          (row) =>
              since == null ||
              DateTime.parse(row[cursorColumn] as String).isAfter(since),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> pullAll(String table) async {
    pullAlls.add(table);
    if (failingPulls.contains(table)) throw Exception('pull failed: $table');
    return [...?serverRows[table]];
  }

  @override
  Future<void> upsertRow(String table, Map<String, dynamic> row) async {
    if (failingRows.contains(row['id'])) {
      throw Exception('rejected ${row['id']}');
    }
    upserts.add((table: table, row: row));
  }

  @override
  Future<void> updateRow(
    String table,
    String id,
    Map<String, dynamic> changes,
  ) async {
    if (failingRows.contains(id)) throw Exception('rejected $id');
    updates.add((table: table, id: id, changes: changes));
  }
}

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  bool online;

  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  void setOnline(bool value) {
    online = value;
    _controller.add(value);
  }

  Future<void> close() => _controller.close();
}

/// Profile row as the backend returns it.
Map<String, dynamic> profileRow({
  String id = 'u1',
  String role = 'farmer',
  String status = 'active',
  String fullName = 'Ana Quispe',
  String? email = 'ana@correo.pe',
}) => {
  'id': id,
  'full_name': fullName,
  'email': email,
  'role': role,
  'status': status,
};

class FakeAuthService implements AuthService {
  FakeAuthService({
    this.userId = 'u1',
    this.password = 'secreto123',
    Map<String, dynamic>? profile,
    this.farmerId = 'f1',
    this.zoneIds = const ['z1'],
  }) : profile = profile ?? profileRow();

  String userId;
  String password;

  /// Row returned by [fetchProfile]; null means "no profile".
  Map<String, dynamic>? profile;
  String? farmerId;
  List<String> zoneIds;

  /// Persisted session, as `restoredUserId` reports it.
  String? sessionUserId;

  /// Thrown by [signInWithPassword] / the fetch methods when set.
  Object? signInError;
  Object? fetchError;

  int signOutCalls = 0;

  final endedController = StreamController<void>.broadcast();

  @override
  Stream<void> get sessionEnded => endedController.stream;

  @override
  Future<String> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final error = signInError;
    if (error != null) throw error;
    if (password != this.password) {
      throw const AuthFailureException(AuthFailure.invalidCredentials);
    }
    sessionUserId = userId;
    return userId;
  }

  @override
  String? restoredUserId() => sessionUserId;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    sessionUserId = null;
  }

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final error = fetchError;
    if (error != null) throw error;
    return profile;
  }

  @override
  Future<String?> fetchFarmerId(String userId) async => farmerId;

  @override
  Future<List<String>> fetchZoneIds(String userId) async => zoneIds;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.signInResult,
    this.restoreResult,
    this.signOutResult,
  });

  Result<AppUser>? signInResult;
  Result<AppUser?>? restoreResult;
  Result<void>? signOutResult;

  final List<({String email, String password, bool farmerOnly})> signIns = [];
  final List<bool> signOuts = [];

  final expiredController = StreamController<void>.broadcast();

  @override
  Stream<void> get sessionExpired => expiredController.stream;

  @override
  Future<Result<AppUser>> signIn(
    String email,
    String password, {
    bool farmerOnly = false,
  }) async {
    signIns.add((email: email, password: password, farmerOnly: farmerOnly));
    return signInResult ??
        const Result.error(
          AuthFailureException(AuthFailure.invalidCredentials),
        );
  }

  @override
  Future<Result<AppUser?>> restore() async =>
      restoreResult ?? const Result.ok(null);

  @override
  Future<Result<void>> signOut({bool force = false}) async {
    signOuts.add(force);
    return signOutResult ?? const Result.ok(null);
  }
}
