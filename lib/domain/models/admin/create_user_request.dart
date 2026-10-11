import 'package:flutter/foundation.dart';

import '../login_identifier.dart';
import '../user_role.dart';

/// Fields of the create-user form that can fail validation.
enum UserFormField { fullName, email, dni, password, phone, zones, community }

/// Data to create an account through the `admin-create-user` Edge Function.
@immutable
class CreateUserRequest {
  const CreateUserRequest({
    required this.role,
    required this.fullName,
    required this.password,
    this.email = '',
    this.dni = '',
    this.phone = '',
    this.zoneIds = const [],
    this.communityId,
    this.ageRange,
  });

  static const minPasswordLength = 8;
  static const ageRanges = ['18-29', '30-39', '40-49', '50-59', '60-69', '70+'];
  static final _phonePattern = RegExp(r'^[0-9+()\s-]{6,20}$');

  final UserRole role;
  final String fullName;
  final String password;
  final String email;
  final String dni;
  final String phone;
  final List<String> zoneIds;
  final String? communityId;
  final String? ageRange;

  bool get isFarmer => role == UserRole.farmer;

  /// Spanish error per invalid field; empty when the request can be sent.
  Map<UserFormField, String> validate() {
    final errors = <UserFormField, String>{};
    if (fullName.trim().length < 2) {
      errors[UserFormField.fullName] = 'Escriba el nombre completo';
    }
    if (password.length < minPasswordLength) {
      errors[UserFormField.password] =
          'La contraseña debe tener al menos $minPasswordLength caracteres';
    }
    if (phone.trim().isNotEmpty && !_phonePattern.hasMatch(phone.trim())) {
      errors[UserFormField.phone] = 'Escriba un teléfono válido';
    }
    if (isFarmer) {
      if (!RegExp(r'^\d{8}$').hasMatch(dni.trim())) {
        errors[UserFormField.dni] = 'El DNI debe tener 8 números';
      }
    } else {
      final parsed = LoginIdentifier.parse(email);
      if (parsed.identifier == null || parsed.identifier!.isDni) {
        errors[UserFormField.email] = 'Escriba un correo válido';
      } else if (parsed.identifier!.value.endsWith(
        '@$agricultoresEmailDomain',
      )) {
        errors[UserFormField.email] = 'Ese dominio es solo para agricultores';
      }
    }
    return errors;
  }

  /// Request body. Farmers send the DNI and no email; staff the opposite.
  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      'password': password,
      'full_name': fullName.trim(),
      'role': role.name,
    };
    if (isFarmer) {
      body['dni'] = dni.trim();
    } else {
      body['email'] = email.trim().toLowerCase();
    }
    if (phone.trim().isNotEmpty) body['phone'] = phone.trim();
    if (zoneIds.isNotEmpty) body['zone_ids'] = zoneIds;
    if (communityId != null) body['community_id'] = communityId;
    if (ageRange != null) body['age_range'] = ageRange;
    return body;
  }
}

/// Outcome of a successful account creation.
@immutable
class CreatedUser {
  const CreatedUser({
    required this.userId,
    required this.role,
    this.farmerId,
    required this.loginIdentifier,
    required this.isDni,
  });

  final String userId;
  final UserRole role;
  final String? farmerId;

  /// DNI or email the person signs in with.
  final String loginIdentifier;
  final bool isDni;

  String get loginHint => isDni
      ? 'Entra con su DNI $loginIdentifier'
      : 'Entra con su correo $loginIdentifier';
}
