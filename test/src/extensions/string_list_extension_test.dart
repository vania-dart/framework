import 'package:test/test.dart';
import 'package:vaniaFramework/src/extensions/string_list_extension.dart';

void main() {
  group('List<String>.joinWithAnd', () {
    test('joins empty list into empty string', () {
      expect(<String>[].joinWithAnd(), equals(''));
    });

    test('handles single element list', () {
      expect(['apple'].joinWithAnd(), equals('apple'));
    });

    test('joins two elements list with custom conjunction', () {
      expect(['apple', 'orange'].joinWithAnd(), equals('apple and orange'));
    });

    test('joins multiple elements with default separator and conjunction', () {
      expect(['apple', 'orange', 'banana'].joinWithAnd(),
          equals('apple, orange and banana'));
    });

    test('allows custom separator and conjunction', () {
      expect(['apple', 'orange', 'banana'].joinWithAnd(' / ', 'or'),
          equals('apple / orange or banana'));
    });

    test('considers only the last two elements for conjunction', () {
      expect(['apple', 'orange', 'banana', 'mango'].joinWithAnd(),
          equals('apple, orange, banana and mango'));
    });
  });
}
