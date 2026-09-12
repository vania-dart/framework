import 'package:test/test.dart';
import 'package:vania/src/cryptographic/vania_encryption.dart';

const _key = 'kQ1spu2E1r452fLa7cSihi7p1pdBR7040H8-UxtXNXg8=';

void main() {
  group('VaniaEncryption', () {
    test(
      'when the same plaintext is encrypted twice, produces different ciphertexts',
      () async {
        final a = await VaniaEncryption.encryptString('hello world', _key);
        final b = await VaniaEncryption.encryptString('hello world', _key);
        expect(a, isNotEmpty);
        expect(b, isNotEmpty);
        expect(a, isNot(equals(b)));
      },
    );

    test('round-trip: decrypt(encrypt(x)) equals x', () async {
      const plain = 'The quick brown fox jumps over the lazy dog 🦊';
      final cipher = await VaniaEncryption.encryptString(plain, _key);
      final round = await VaniaEncryption.decryptString(cipher, _key);
      expect(round, equals(plain));
    });

    test('round-trip on empty string succeeds', () async {
      final cipher = await VaniaEncryption.encryptString('', _key);
      final round = await VaniaEncryption.decryptString(cipher, _key);
      expect(round, equals(''));
    });

    test('round-trip on JSON payload preserves structure', () async {
      const payload = '{"data":{"user":42,"role":"admin"},"expiration":9999}';
      final cipher = await VaniaEncryption.encryptString(payload, _key);
      final round = await VaniaEncryption.decryptString(cipher, _key);
      expect(round, equals(payload));
    });

    test(
      'decrypt with wrong key returns empty string (does not throw)',
      () async {
        final cipher = await VaniaEncryption.encryptString('secret', _key);
        final wrong = await VaniaEncryption.decryptString(cipher, 'other-key');
        expect(wrong, equals(''));
      },
    );
  });
}
