import 'dart:io';

import '../common/console.dart';
import '../utils/process_runner.dart';
import 'command.dart';

class MigrateCommand extends Command {
  @override
  String get name => 'migrate';

  @override
  String get description => 'Run the database migrations';

  @override
  Future<int> execute(List<String> arguments) async {
    final script =
        '${workingDirectory.path}/lib/database/migrations/migrate.dart';
    if (!File(script).existsSync()) {
      Console.error('No migration runner exists.');
      return ExitCode.noInput;
    }

    Console.info('Running migrations…');
    final code = await runStreaming('dart', [
      'run',
      script,
      ...arguments,
    ], workingDirectory: workingDirectory.path);
    if (code != 0) {
      Console.error('Migration failed.');
      return ExitCode.failure;
    }
    Console.success('Migrations complete');
    return ExitCode.success;
  }
}
