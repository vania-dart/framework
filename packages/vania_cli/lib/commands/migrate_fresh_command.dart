import 'dart:io';

import '../common/console.dart';
import '../utils/process_runner.dart';
import 'command.dart';

class MigrateFreshCommand extends Command {
  MigrateFreshCommand({
    required this.commandName,
    required this.flag,
    required this.description,
  });

  final String commandName;
  final String flag;
  @override
  final String description;

  @override
  String get name => commandName;

  @override
  Future<int> execute(List<String> arguments) async {
    final script =
        '${workingDirectory.path}/lib/database/migrations/migrate.dart';
    if (!File(script).existsSync()) {
      Console.error('No migration runner exists.');
      return ExitCode.noInput;
    }
    final code = await runStreaming('dart', [
      'run',
      script,
      flag,
      ...arguments,
    ], workingDirectory: workingDirectory.path);
    return code == 0 ? ExitCode.success : ExitCode.failure;
  }
}
