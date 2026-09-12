import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';

void main() {
  group('Application.initialize APP_KEY validation', () {
    bool appKeyValid(dynamic key) => key is String && key.length >= 32;

    test('accepts a 32-character key', () {
      expect(appKeyValid('a' * 32), isTrue);
    });

    test('rejects a short key', () {
      expect(appKeyValid('short'), isFalse);
    });

    test('rejects null', () {
      expect(appKeyValid(null), isFalse);
    });

    test('rejects non-string values', () {
      expect(appKeyValid(12345), isFalse);
    });

    test('the test env key satisfies the guard', () {
      Env().load(file: File('test/.env'));
      expect(appKeyValid(Env().env['APP_KEY']), isTrue);
    });
  });
}
