import 'dart:io';

import '../common/console.dart';
import '../utils/process_runner.dart';
import 'command.dart';

class MigrateDatabaseSeederCommand extends Command {
  @override
  String get name => 'migrate:seed';

  @override
  String get description => 'Run the database seeders';

  @override
  Future<int> execute(List<String> arguments) async {
    final script =
        '${workingDirectory.path}/lib/database/seeders/database_seeder.dart';
    if (!File(script).existsSync()) {
      Console.error('No database seeder exists.');
      return ExitCode.noInput;
    }

    Console.info('Seeding…');
    final code = await runStreaming('dart', [
      'run',
      script,
      ...arguments,
    ], workingDirectory: workingDirectory.path);
    if (code != 0) {
      Console.error('Seeding failed.');
      return ExitCode.failure;
    }
    Console.success('Seeding complete');
    return ExitCode.success;
  }
}
