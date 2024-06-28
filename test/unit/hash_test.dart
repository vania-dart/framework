import 'dart:io';

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
  });
}
