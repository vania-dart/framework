import 'dart:convert';
import 'dart:io';

import '../common/console.dart';

/// Starts a process, streams both output channels, and returns its exit code.
Future<int> runStreaming(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  String Function(String line)? transform,
}) async {
  final Process process;
  try {
    process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
  } on ProcessException catch (error) {
    Console.error('Could not run $executable: ${error.message}');
    return 1;
  }

  Future<void> forward(Stream<List<int>> source, IOSink sink) async {
    await for (final line in source
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.isEmpty) continue;
      sink.writeln(transform?.call(line) ?? line);
    }
  }

  final forwards = <Future<void>>[
    forward(process.stdout, stdout),
    forward(process.stderr, stderr),
  ];
  final exitCode = await process.exitCode;
  await Future.wait(forwards);
  return exitCode;
}
