import 'package:test/test.dart';
import 'package:vania/src/utils/functions.dart';

void main() {
  group('randomString', () {
    test('when called twice with default length returns distinct values', () {
      final a = randomString();
      final b = randomString();
      expect(a, isNot(equals(b)));
    });

    test('when called 100 times produces 100 unique values', () {
      final samples = List.generate(100, (_) => randomString(length: 32));
      expect(samples.toSet().length, equals(100));
    });

    test('when length is 32 returns exactly 32 chars', () {
      expect(randomString(length: 32).length, equals(32));
    });

    test(
      'when numbers flag on, character set includes digits somewhere in 500 samples',
      () {
        final joined = List.generate(
          500,
          (_) => randomString(numbers: true),
        ).join();
        expect(joined.contains(RegExp(r'[0-9]')), isTrue);
      },
    );
  });

  group('randomInt', () {
    test('when called with default length returns 6-char string', () {
      expect(randomInt().length, equals(6));
    });

    test('when called 100 times produces at least 90 unique values', () {
      final samples = List.generate(100, (_) => randomInt()).toSet();
      expect(samples.length, greaterThanOrEqualTo(90));
    });
  });
}
