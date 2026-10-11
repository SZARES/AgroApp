/// Email domain that backs every farmer login: a farmer signs in with the DNI
/// and Supabase Auth sees `<dni>@agricultores.agroapp`.
const agricultoresEmailDomain = 'agricultores.agroapp';

/// How a person identifies themselves on the login form.
enum LoginIdentifierKind { dni, email }

/// Why raw input is not a usable login identifier.
enum LoginIdentifierError {
  /// Only digits, but not exactly 8 of them.
  invalidDni,

  /// Contains '@' but is not a plausible email, or is neither digits nor email.
  invalidIdentifier,
}

/// A validated login identifier: a farmer's DNI or anyone else's email.
///
/// This is the single place that knows how a DNI becomes an auth email.
final class LoginIdentifier {
  const LoginIdentifier._(this.kind, this.value);

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _digitsPattern = RegExp(r'^\d+$');
  static const dniLength = 8;

  final LoginIdentifierKind kind;

  /// The 8-digit DNI, or the lowercased email.
  final String value;

  bool get isDni => kind == LoginIdentifierKind.dni;

  /// Email to hand to Supabase Auth.
  String get authEmail => isDni ? '$value@$agricultoresEmailDomain' : value;

  /// Parses [raw] (trimmed). An error is returned, never thrown.
  static ({LoginIdentifier? identifier, LoginIdentifierError? error}) parse(
    String raw,
  ) {
    final text = raw.trim();
    if (text.contains('@')) {
      final email = text.toLowerCase();
      if (_emailPattern.hasMatch(email)) {
        return (
          identifier: LoginIdentifier._(LoginIdentifierKind.email, email),
          error: null,
        );
      }
      return (identifier: null, error: LoginIdentifierError.invalidIdentifier);
    }
    if (_digitsPattern.hasMatch(text)) {
      if (text.length == dniLength) {
        return (
          identifier: LoginIdentifier._(LoginIdentifierKind.dni, text),
          error: null,
        );
      }
      return (identifier: null, error: LoginIdentifierError.invalidDni);
    }
    return (identifier: null, error: LoginIdentifierError.invalidIdentifier);
  }

  @override
  bool operator ==(Object other) =>
      other is LoginIdentifier && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'LoginIdentifier(${kind.name}, $value)';
}
