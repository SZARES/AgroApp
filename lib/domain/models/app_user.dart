import 'package:flutter/foundation.dart';

import 'user_role.dart';

enum UserStatus { active, inactive, suspended }

/// The signed-in person: profile data plus the ids the app needs to scope
/// data (the farmer id for farmers, the assigned zones for staff).
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
    this.farmerId,
    this.zoneIds = const [],
  });

  /// `auth.users.id` (also `profiles.id`).
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final UserStatus status;

  /// `farmers.id`; parcels, incidents and storage paths use this, not [id].
  final String? farmerId;
  final List<String> zoneIds;

  bool get isActive => status == UserStatus.active;

  /// Builds a user from a `profiles` row; null when the row is unusable
  /// (unknown role). An unknown status counts as inactive.
  static AppUser? fromProfile(
    Map<String, dynamic> profile, {
    String? farmerId,
    List<String> zoneIds = const [],
    String fallbackEmail = '',
  }) {
    final id = profile['id'];
    final role = UserRole.values.asNameMap()['${profile['role']}'];
    if (id is! String || role == null) return null;
    return AppUser(
      id: id,
      email: (profile['email'] as String?) ?? fallbackEmail,
      fullName: (profile['full_name'] as String?) ?? '',
      role: role,
      status:
          UserStatus.values.asNameMap()['${profile['status']}'] ??
          UserStatus.inactive,
      farmerId: farmerId,
      zoneIds: List.unmodifiable(zoneIds),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'role': role.name,
    'status': status.name,
    'farmer_id': farmerId,
    'zone_ids': zoneIds,
  };

  /// Reads what [toJson] wrote; null when [json] is not a valid user.
  static AppUser? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final zones = map['zone_ids'];
    return fromProfile(
      map,
      farmerId: map['farmer_id'] as String?,
      zoneIds: zones is List ? [for (final z in zones) '$z'] : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.email == email &&
      other.fullName == fullName &&
      other.role == role &&
      other.status == status &&
      other.farmerId == farmerId &&
      listEquals(other.zoneIds, zoneIds);

  @override
  int get hashCode => Object.hash(
    id,
    email,
    fullName,
    role,
    status,
    farmerId,
    Object.hashAll(zoneIds),
  );

  @override
  String toString() => 'AppUser($id, ${role.name}, ${status.name})';
}
