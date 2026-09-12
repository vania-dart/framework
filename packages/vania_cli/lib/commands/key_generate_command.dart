import 'dart:io';

import '../common/console.dart';
import '../utils/functions.dart';
import 'command.dart';

class KeyGenerateCommand extends Command {
  @override
  String get name => 'key:generate';

  @override
  String get description => 'Generate APP_KEY and write it to .env';

  @override
  String get usage => '[--show] [--force]';

  @override
  Future<int> execute(List<String> arguments) async {
    for (final argument in arguments) {
      if (argument == '--show' || argument == '--force') continue;
      Console.error('Unknown option: $argument');
      return ExitCode.usage;
    }

    final key = generateRandomKey();
    if (arguments.contains('--show')) {
      Console.line(key);
      return ExitCode.success;
    }

    final envFile = File('${workingDirectory.path}/.env');
    if (!envFile.existsSync()) {
      Console.error('.env does not exist in the project root.');
      return ExitCode.noInput;
    }

    final lines = await envFile.readAsLines();
    final index = lines.indexWhere(
      (line) => line.trimLeft().startsWith('APP_KEY='),
    );
    final force = arguments.contains('--force');

    if (index >= 0) {
      final current = lines[index].split('=').skip(1).join('=').trim();
      if (current.isNotEmpty && !force) {
        Console.warn('APP_KEY is already set. Use --force to replace it.');
        return ExitCode.success;
      }
      lines[index] = 'APP_KEY=$key';
    } else {
      lines.add('APP_KEY=$key');
    }

    await envFile.writeAsString('${lines.join('\n')}\n');
    Console.success('APP_KEY written to .env');
    return ExitCode.success;
  }
}
