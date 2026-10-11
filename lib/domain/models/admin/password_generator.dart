import 'dart:math';

/// Strong random passwords for new accounts.
abstract final class PasswordGenerator {
  static const length = 12;
  static const _lower = 'abcdefghijkmnopqrstuvwxyz';
  static const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _digits = '23456789';
  static const _symbols = '!@#\$%*?';
  static const charset = _lower + _upper + _digits + _symbols;

  /// A [length]-char password with at least one of each character class.
  /// Pass a [random] for deterministic tests; defaults to a secure source.
  static String generate({Random? random}) {
    final rng = random ?? Random.secure();
    String pick(String chars) => chars[rng.nextInt(chars.length)];
    final chars = [
      pick(_lower),
      pick(_upper),
      pick(_digits),
      pick(_symbols),
      for (var i = 4; i < length; i++) pick(charset),
    ]..shuffle(rng);
    return chars.join();
  }
}
