import 'package:flutter/foundation.dart';

import '../app_user.dart';
import '../user_role.dart';

/// A person account as the admin sees it, joined from the replica
/// (`profiles`, `farmers`, `user_zones`, `communities`).
@immutable
class AdminUser {
  const AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    this.phone,
    this.farmerId,
    this.dni,
    this.communityId,
    this.communityName,
    this.ageRange,
    this.lastActivityAt,
    this.zoneIds = const [],
    this.zoneNames = const [],
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final UserStatus status;
  final String? phone;
  final String? farmerId;
  final String? dni;
  final String? communityId;
  final String? communityName;
  final String? ageRange;
  final DateTime? lastActivityAt;
  final List<String> zoneIds;
  final List<String> zoneNames;

  bool get isFarmer => role == UserRole.farmer;

  /// What the person types to sign in.
  String get loginIdentifier => isFarmer && dni != null ? dni! : email;

  /// Short line under the name in the list.
  String get subtitle {
    final parts = <String>[
      if (isFarmer && dni != null) 'DNI $dni',
      ?communityName,
      if (!isFarmer && zoneNames.isNotEmpty) zoneNames.join(', '),
    ];
    return parts.isEmpty ? (isFarmer ? '' : email) : parts.join(' · ');
  }

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return fullName.toLowerCase().contains(needle) ||
        email.toLowerCase().contains(needle) ||
        (dni?.contains(needle) ?? false);
  }
}

String roleLabel(UserRole role) => switch (role) {
  UserRole.farmer => 'Agricultor',
  UserRole.technician => 'Técnico',
  UserRole.supervisor => 'Supervisor',
  UserRole.admin => 'Administrador',
};

String statusLabel(UserStatus status) => switch (status) {
  UserStatus.active => 'Activo',
  UserStatus.inactive => 'Inactivo',
  UserStatus.suspended => 'Suspendido',
};
