import 'dart:convert';
import 'dart:io';

// `crypto` also exports a `Hash` type, so the framework's is prefixed.
import 'package:crypto/crypto.dart' as crypto;
import 'package:test/test.dart';
import 'package:vania/vania.dart';

void main() {
  group('Hash class test', () {
    setUp(() {
      Env().load(file: File('test/.env'));
    });

    test('Make/Verify correct paswword', () {
      String password = "123456789";
      String hash = Hash().make(password);
      expect(Hash().verify(password, hash), true);
    });

    test('Make/Verify wrong password', () {
      String password = "123456789";
      String hash = Hash().make(password);
      expect(Hash().verify("12345678", hash), false);
    });

    test('make uses the versioned format', () {
      expect(Hash().make('123456789'), startsWith('vania1\$'));
    });

    test('same password hashes differently each time (unique salt)', () {
      // Two hashes of the same password must never come out equal.
      expect(Hash().make('123456789'), isNot(equals(Hash().make('123456789'))));
    });

    test('legacy 4-char-salt hashes still verify', () {
      // The legacy layout: 4 salt characters followed by base64 of a
      // single HMAC-SHA512 round over salt + password.
      const salt = 'aB3x';
      const password = '123456789';
      final hmac = crypto.Hmac(
        crypto.sha512,
        utf8.encode(env<String>('APP_KEY')),
      );
      final legacy =
          salt +
          base64.encode(hmac.convert(utf8.encode(salt + password)).bytes);

      expect(
        Hash().verify(password, legacy),
        isTrue,
        reason: 'passwords stored under the older scheme must verify',
      );
      expect(Hash().verify('wrong', legacy), isFalse);
      expect(
        Hash().needsRehash(legacy),
        isTrue,
        reason: 'legacy hashes must be flagged for migration',
      );
    });

    test('current-format hashes do not need a rehash', () {
      expect(Hash().needsRehash(Hash().make('123456789')), isFalse);
    });

    test('malformed hashes return false instead of throwing', () {
      for (final bad in ['', 'x', 'vania1\$', 'vania1\$onlypart']) {
        expect(Hash().verify('123456789', bad), isFalse, reason: 'input: $bad');
      }
    });
  });
}
