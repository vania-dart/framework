import 'package:test/test.dart';
import 'package:vania/src/extensions/date_time_extension.dart';

void main() {
  group('DateTimeExtension Tests', () {
    test('toAwsFormat produces correct AWS timestamp format', () {
      var dateTime = DateTime(2023, 1, 2, 3, 4, 5);
      expect(dateTime.toAwsFormat(), equals('20230102T030405Z'));
    });

    test('format produces correctly formatted date-time string', () {
      var dateTime = DateTime(2023, 1, 2, 3, 4, 5);
      expect(dateTime.format(), equals('2023-01-02 03:04:05'));
    });

    test('toAwsFormat handles single-digit and double-digit fields', () {
      var dateTime = DateTime(2023, 11, 20, 10, 9, 8);
      expect(dateTime.toAwsFormat(), equals('20231120T100908Z'));
    });

    test('format handles edge case of leap year date', () {
      var dateTime = DateTime(2020, 2, 29, 23, 59, 59);
      expect(dateTime.format(), equals('2020-02-29 23:59:59'));
    });
  });
}
