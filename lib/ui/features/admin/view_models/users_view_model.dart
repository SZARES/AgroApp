import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/repositories/local_store.dart';
import '../../../../domain/models/admin/admin_failure.dart';
import '../../../../domain/models/admin/admin_user.dart';
import '../../../../domain/models/app_user.dart';
import '../../../../domain/models/user_role.dart';
import '../../../../utils/result.dart';

/// Users list and detail: filters, search and account management.
class AdminUsersViewModel extends ChangeNotifier {
  AdminUsersViewModel({required AdminRepository repository})
    : _repository = repository {
    _listen();
  }

  final AdminRepository _repository;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  List<AdminUser> _users = const [];
  List<JsonMap> _zones = const [];
  List<JsonMap> _communities = const [];
  List<JsonMap> _parcels = const [];
  List<JsonMap> _technicianParcels = const [];

  bool _loading = true;
  Object? _loadError;
  String _query = '';
  UserRole? _roleFilter;
  UserStatus? _statusFilter;
  String? _selectedId;
  bool _creating = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  bool get loading => _loading;
  bool get hasLoadError => _loadError != null;
  List<AdminUser> get users => _users;
  List<JsonMap> get zones => _zones;
  List<JsonMap> get communities => _communities;
  String get query => _query;
  UserRole? get roleFilter => _roleFilter;
  UserStatus? get statusFilter => _statusFilter;
  bool get creating => _creating;
  bool get busy => _busy;

  /// Last action outcome in Spanish, for a snackbar or banner.
  String? get message => _message;
  bool get messageIsError => _messageIsError;

  AdminUser? get selected {
    for (final user in _users) {
      if (user.id == _selectedId) return user;
    }
    return null;
  }

  List<AdminUser> get visible => [
    for (final user in _users)
      if ((_roleFilter == null || user.role == _roleFilter) &&
          (_statusFilter == null || user.status == _statusFilter) &&
          user.matches(_query))
        user,
  ];

  /// Parcels a technician can be assigned: those in the technician's zones.
  List<JsonMap> assignableParcels(AdminUser technician) => [
    for (final parcel in _parcels)
      if (technician.zoneIds.contains('${parcel['zone_id']}')) parcel,
  ];

  Set<String> assignedParcelIds(String technicianId) => {
    for (final row in _technicianParcels)
      if (row['technician_id'] == technicianId) '${row['parcel_id']}',
  };

  void _listen() {
    _loading = true;
    _loadError = null;
    _subscriptions.add(
      _repository.watchUsers().listen((users) {
        _users = users;
        _loading = false;
        _loadError = null;
        notifyListeners();
      }, onError: _onLoadError),
    );
    void table(String name, void Function(List<JsonMap>) assign) {
      _subscriptions.add(
        _repository.watchRows(name).listen((rows) {
          assign(rows);
          notifyListeners();
        }, onError: _onLoadError),
      );
    }

    table('zones', (rows) => _zones = rows);
    table('communities', (rows) => _communities = rows);
    table('parcels', (rows) => _parcels = rows);
    table('technician_parcels', (rows) => _technicianParcels = rows);
  }

  void _onLoadError(Object error) {
    _loadError = error;
    _loading = false;
    notifyListeners();
  }

  /// Subscribes again after a load error.
  Future<void> retry() async {
    await _cancel();
    _listen();
    notifyListeners();
  }

  Future<void> _cancel() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setRoleFilter(UserRole? role) {
    _roleFilter = role;
    notifyListeners();
  }

  void setStatusFilter(UserStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void select(String id) {
    _selectedId = id;
    _creating = false;
    _message = null;
    notifyListeners();
  }

  void startCreate() {
    _creating = true;
    _selectedId = null;
    _message = null;
    notifyListeners();
  }

  void cancelCreate() {
    _creating = false;
    notifyListeners();
  }

  /// Called by the create form once the account exists.
  void onCreated(String userId) {
    _selectedId = userId;
  }

  void clearMessage() {
    _message = null;
    notifyListeners();
  }

  Future<bool> saveProfile(AdminUser user, String fullName, String phone) {
    if (fullName.trim().length < 2) {
      return _fail('Escriba el nombre completo');
    }
    return _run(
      () =>
          _repository.updateProfile(user.id, fullName: fullName, phone: phone),
      'Datos guardados',
    );
  }

  Future<bool> setStatus(AdminUser user, UserStatus status) {
    if (user.id == _repository.currentUserId && status != UserStatus.active) {
      return _fail('No puede desactivar su propia cuenta');
    }
    return _run(
      () => _repository.setUserStatus(user.id, status),
      'Estado actualizado',
    );
  }

  Future<bool> resetPassword(AdminUser user, String password) {
    if (password.length < 8) {
      return _fail('La contraseña debe tener al menos 8 caracteres');
    }
    return _run(
      () => _repository.resetPassword(user.id, password),
      'Contraseña cambiada',
    );
  }

  Future<bool> saveZones(AdminUser user, List<String> zoneIds) =>
      _run(() => _repository.setUserZones(user.id, zoneIds), 'Zonas guardadas');

  Future<bool> saveParcels(AdminUser technician, List<String> parcelIds) =>
      _run(
        () => _repository.setTechnicianParcels(technician.id, parcelIds),
        'Parcelas guardadas',
      );

  Future<bool> _fail(String text) async {
    _message = text;
    _messageIsError = true;
    notifyListeners();
    return false;
  }

  Future<bool> _run(
    Future<Result<void>> Function() action,
    String okText,
  ) async {
    _busy = true;
    _message = null;
    notifyListeners();
    final result = await action();
    _busy = false;
    final ok = result is Ok<void>;
    _message = switch (result) {
      Ok() => okText,
      Error(:final error) =>
        error is AdminFailureException
            ? error.message
            : 'No se pudo completar la acción. Intente de nuevo.',
    };
    _messageIsError = !ok;
    notifyListeners();
    return ok;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
