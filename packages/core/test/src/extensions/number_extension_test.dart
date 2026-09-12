import 'package:test/test.dart';
import 'package:vania/src/extensions/number_extension.dart';

void main() {
  group('NumberExtension.toFixed', () {
    test('should round a double to 2 decimal places', () {
      expect(123.456.toFixed(2), equals(123.46));
    });

    test('should round a double to 0 decimal places', () {
      expect(123.456.toFixed(0), equals(123));
    });

    test('should handle integers correctly', () {
      expect(123.toFixed(0), equals(123));
      expect(123.toFixed(2), equals(123.00));
    });

    test('should handle rounding up correctly', () {
      expect(123.556.toFixed(2), equals(123.56));
    });

    test('should handle rounding down correctly', () {
      expect(123.554.toFixed(2), equals(123.55));
    });

    test('should process very small decimals', () {
      expect(0.000123456.toFixed(4), equals(0.0001));
    });

    test('should return a double when rounding integers with decimals', () {
      var result = 100.toFixed(2);
      expect(result, equals(100.00));
      expect(result, isA<double>());
    });

    test(
      'should return an integer when rounding integers with zero decimals',
      () {
        var result = 100.toFixed(0);
        expect(result, equals(100));
        expect(result, isA<int>());
      },
    );

    test('should handle negative numbers correctly', () {
      expect((-123.456).toFixed(2), equals(-123.46));
      expect((-123.456).toFixed(0), equals(-123));
    });
  });
}
