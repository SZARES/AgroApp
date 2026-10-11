import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/repositories/local_store.dart';
import '../../../../domain/models/admin/admin_failure.dart';
import '../../../../domain/models/admin/create_user_request.dart';
import '../../../../domain/models/admin/password_generator.dart';
import '../../../../domain/models/user_role.dart';
import '../../../../utils/result.dart';

/// State of the "Crear usuario" form. The role is chosen first and decides
/// which fields apply.
class CreateUserViewModel extends ChangeNotifier {
  CreateUserViewModel({
    required AdminRepository repository,
    required this.zones,
    required this.communities,
    Random? random,
  }) : _repository = repository,
       _random = random;

  final AdminRepository _repository;
  final Random? _random;
  final List<JsonMap> zones;
  final List<JsonMap> communities;

  UserRole? _role;
  String fullName = '';
  String email = '';
  String dni = '';
  String phone = '';
  String password = '';
  String? ageRange;
  String? communityId;
  String? filterZoneId;
  final Set<String> zoneIds = {};

  bool _submitted = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  CreatedUser? _created;
  String? _revealedPassword;

  UserRole? get role => _role;
  bool get busy => _busy;
  bool get showPassword => _showPassword;
  bool get submitted => _submitted;

  /// Server or connectivity problem of the last submit, in Spanish.
  String? get error => _error;

  /// Set after a successful creation; show once, then [dismissReveal].
  CreatedUser? get created => _created;

  /// The password of the account just created; null once dismissed.
  String? get revealedPassword => _revealedPassword;

  /// Roles an admin can create.
  static const creatableRoles = UserRole.values;

  /// Communities of [filterZoneId] (all when no zone is picked).
  List<JsonMap> get availableCommunities => [
    for (final community in communities)
      if (filterZoneId == null || community['zone_id'] == filterZoneId)
        community,
  ];

  bool get needsZones =>
      _role == UserRole.technician || _role == UserRole.supervisor;

  CreateUserRequest get request => CreateUserRequest(
    role: _role ?? UserRole.farmer,
    fullName: fullName,
    password: password,
    email: email,
    dni: dni,
    phone: phone,
    zoneIds: needsZones ? zoneIds.toList() : const [],
    communityId: _role == UserRole.farmer ? communityId : null,
    ageRange: _role == UserRole.farmer ? ageRange : null,
  );

  /// Field errors, only after the first submit attempt.
  Map<UserFormField, String> get errors {
    if (!_submitted || _role == null) return const {};
    return request.validate();
  }

  void setRole(UserRole role) {
    if (_role == role) return;
    _role = role;
    zoneIds.clear();
    communityId = null;
    filterZoneId = null;
    ageRange = null;
    email = '';
    dni = '';
    _error = null;
    notifyListeners();
  }

  /// Rebuilds after a plain text edit (keeps text fields in the controllers).
  void changed() {
    notifyListeners();
  }

  void setFilterZone(String? zoneId) {
    filterZoneId = zoneId;
    final stillValid = availableCommunities.any((c) => c['id'] == communityId);
    if (!stillValid) communityId = null;
    notifyListeners();
  }

  void setCommunity(String? id) {
    communityId = id;
    notifyListeners();
  }

  void setAgeRange(String? value) {
    ageRange = value;
    notifyListeners();
  }

  void toggleZone(String zoneId, bool selected) {
    selected ? zoneIds.add(zoneId) : zoneIds.remove(zoneId);
    notifyListeners();
  }

  void toggleShowPassword() {
    _showPassword = !_showPassword;
    notifyListeners();
  }

  /// Fills a strong random password and shows it so it can be copied.
  String generatePassword() {
    password = PasswordGenerator.generate(random: _random);
    _showPassword = true;
    notifyListeners();
    return password;
  }

  /// Validates and creates the account. Returns true on success.
  Future<bool> submit() async {
    _submitted = true;
    _error = null;
    if (_role == null || request.validate().isNotEmpty) {
      notifyListeners();
      return false;
    }
    _busy = true;
    notifyListeners();
    final sent = request;
    final result = await _repository.createUser(sent);
    _busy = false;
    switch (result) {
      case Ok(:final value):
        _created = value;
        _revealedPassword = sent.password;
        password = '';
        _showPassword = false;
        notifyListeners();
        return true;
      case Error(:final error):
        _error = error is AdminFailureException
            ? error.message
            : 'No se pudo crear la cuenta. Intente de nuevo.';
        notifyListeners();
        return false;
    }
  }

  /// Forgets the created account and its one-time password.
  void dismissReveal() {
    _created = null;
    _revealedPassword = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _revealedPassword = null;
    password = '';
    super.dispose();
  }
}
