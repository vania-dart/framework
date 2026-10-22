// ignore_for_file: constant_identifier_names
import 'dart:io';
import '../utils/helper.dart';

class Logger {
  static const EMERGENCY = 'EMERGENCY';
  static const ALERT = 'ALERT';
  static const CRITICAL = 'CRITICAL';
  static const ERROR = 'ERROR';
  static const SUCCESS = 'SUCCESS';
  static const WARNING = 'WARNING';
  static const NOTICE = 'NOTICE';
  static const INFO = 'INFO';
  static const DEBUG = 'DEBUG';

  /// One open sink per log file, kept for the life of the process.
  ///
  /// Opening a file per entry costs a directory check and a file
  /// descriptor each time, and under a burst of errors the descriptors
  /// pile up faster than they close.
  static final Map<String, IOSink> _sinks = <String, IOSink>{};

  /// Appends [content] to `storage/logs/<fileName>.log`.
  ///
  /// Never throws: logging is called from error handlers, and a failure
  /// here must not turn one error into another. An entry that cannot be
  /// written goes to stderr instead.
  static void log(
    String content, {
    String type = INFO,
    String fileName = 'vania',
  }) {
    final now = DateTime.now();

    var text =
        "[${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}]";
    text += ' $type: ';
    text += content;
    text += '\n';

    try {
      _sinkFor(fileName).write(text);
    } catch (_) {
      stderr.write(text);
    }
  }

  static IOSink _sinkFor(String fileName) {
    final existing = _sinks[fileName];
    if (existing != null) return existing;

    final directory = Directory(storagePath('logs'));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final sink = File(
      '${directory.path}/$fileName.log',
    ).openWrite(mode: FileMode.append);
    _sinks[fileName] = sink;

    // A failed write surfaces here, asynchronously. Left unhandled it
    // would stop the isolate; instead the sink is dropped so the next
    // entry opens the file afresh.
    sink.done.catchError((Object e) {
      if (identical(_sinks[fileName], sink)) _sinks.remove(fileName);
      stderr.writeln('Logger: cannot write $fileName.log: $e');
    });
    return sink;
  }

  /// Writes out every buffered entry and closes the open log files.
  ///
  /// Call before the process exits so buffered entries are not lost.
  /// Logging afterwards reopens the files.
  static Future<void> flush() async {
    final sinks = _sinks.values.toList();
    _sinks.clear();
    for (final sink in sinks) {
      try {
        await sink.close();
      } catch (_) {}
    }
  }
}
