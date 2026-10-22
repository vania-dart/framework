import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/logger/logger.dart';
import 'package:vania/src/utils/helper.dart';

void main() {
  const name = 'logger_test';
  final file = File('${storagePath('logs')}/$name.log');

  setUp(() async {
    await Logger.flush();
    if (file.existsSync()) file.deleteSync();
  });

  tearDown(() async {
    await Logger.flush();
    if (file.existsSync()) file.deleteSync();
  });

  test('a burst of entries all reach the file, whole and in order', () async {
    const count = 2000;
    for (var i = 0; i < count; i++) {
      Logger.log('entry $i', type: Logger.ERROR, fileName: name);
    }
    await Logger.flush();

    final lines = file.readAsLinesSync();
    expect(lines, hasLength(count));
    for (var i = 0; i < count; i++) {
      expect(lines[i], endsWith(' ERROR: entry $i'));
    }
  });

  test('a log file that cannot be written does not raise an error, and '
      'other log files keep working', () async {
    // The directory does not exist, so the write fails asynchronously.
    Logger.log('lost', fileName: 'no/such/dir/$name');
    Logger.log('kept', fileName: name);
    await Logger.flush();

    expect(file.readAsLinesSync().single, endsWith(' INFO: kept'));
  });
}
