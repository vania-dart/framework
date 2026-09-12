import 'dart:io';

import '../common/console.dart';
import '../utils/process_runner.dart';
import 'command.dart';

class BuildCommand extends Command {
  @override
  String get name => 'build';

  @override
  String get description => 'Compile the app to a native executable';

  @override
  String get usage => '[--output <path>]';

  @override
  Future<int> execute(List<String> arguments) async {
    var output = 'bin/server';
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument != '--output' && argument != '-o') {
        Console.error('Unknown option: $argument');
        return ExitCode.usage;
      }
      if (index + 1 >= arguments.length) {
        Console.error('$argument needs a value.');
        return ExitCode.usage;
      }
      output = arguments[++index];
    }

    if (!File('${workingDirectory.path}/bin/server.dart').existsSync()) {
      Console.error('bin/server.dart does not exist.');
      return ExitCode.noInput;
    }

    Console.info('Compiling…');
    final stopwatch = Stopwatch()..start();
    final code = await runStreaming('dart', [
      'compile',
      'exe',
      'bin/server.dart',
      '-o',
      output,
    ], workingDirectory: workingDirectory.path);
    if (code != 0) {
      Console.error('Build failed.');
      return ExitCode.failure;
    }

    Console.success(
      'Built ${Console.cyan(output)} '
      '${Console.dim('(${stopwatch.elapsedMilliseconds}ms)')}',
    );
    return ExitCode.success;
  }
}
