import 'package:test/test.dart';
import 'package:vania/src/extensions/string_extension.dart';

void main() {
  group("toInt extension test", () {
    test("should return int value", () {
      expect("1".toInt(), 1);
    });

    test("should return null when it is string", () {
      expect("a".toInt(), null);
    });
    test("should return null when it is double", () {
      expect("1,25".toInt(), null);
    });
  });
}
