import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/domain/models/login_identifier.dart';

void main() {
  group('LoginIdentifier.parse', () {
    test('8 digits is a DNI with the derived email', () {
      final parsed = LoginIdentifier.parse('12345678');

      expect(parsed.error, isNull);
      expect(parsed.identifier!.kind, LoginIdentifierKind.dni);
      expect(parsed.identifier!.isDni, isTrue);
      expect(parsed.identifier!.authEmail, '12345678@agricultores.agroapp');
      expect(agricultoresEmailDomain, 'agricultores.agroapp');
    });

    for (final digits in ['1234567', '123456789', '1']) {
      test('${digits.length} digits is an invalid DNI', () {
        final parsed = LoginIdentifier.parse(digits);

        expect(parsed.identifier, isNull);
        expect(parsed.error, LoginIdentifierError.invalidDni);
      });
    }

    test('an email is kept as is', () {
      final parsed = LoginIdentifier.parse('tec@correo.pe');

      expect(parsed.identifier!.kind, LoginIdentifierKind.email);
      expect(parsed.identifier!.authEmail, 'tec@correo.pe');
    });

    test('whitespace is trimmed and an email is lowercased', () {
      expect(
        LoginIdentifier.parse('  Tec@Correo.PE ').identifier!.authEmail,
        'tec@correo.pe',
      );
      expect(
        LoginIdentifier.parse(' 12345678\n').identifier!.value,
        '12345678',
      );
    });

    for (final junk in [
      '',
      'ana',
      '1234abcd',
      '12 345 678',
      '@',
      'a@b',
      'a b@c.d',
    ]) {
      test('"$junk" is an invalid identifier', () {
        final parsed = LoginIdentifier.parse(junk);

        expect(parsed.identifier, isNull);
        expect(parsed.error, LoginIdentifierError.invalidIdentifier);
      });
    }
  });
}
