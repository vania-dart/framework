import 'dart:io';

import '../common/console.dart';
import 'command.dart';

const String authMigrationContent = '''
import 'package:vania/migration.dart';

class CreatePersonalAccessTokensTable extends Migration {
  @override
  Future<void> up() async {
    await create('personal_access_tokens', (Schema table) {
      table.id();
      table.tinyText('name');
      table.bigInt('tokenable_id');
      table.string('token').unique();
      table.timeStamp('last_used_at').nullable();
      table.timeStamps();
      table.timeStamp('deleted_at').nullable();
    });
  }

  @override
  Future<void> down() async {
    await drop('personal_access_tokens');
  }
}
''';

class AuthCommand extends Command {
  @override
  String get name => 'make:auth';

  @override
  String get description => 'Create the personal access tokens migration';

  @override
  Future<int> execute(List<String> arguments) async {
    if (arguments.isNotEmpty) {
      Console.error('make:auth does not accept arguments.');
      return ExitCode.usage;
    }

    const fileName = 'create_personal_access_tokens_table.dart';
    final file = File(
      '${workingDirectory.path}/lib/database/migrations/$fileName',
    );
    if (file.existsSync()) {
      Console.error('The personal access tokens migration already exists.');
      return ExitCode.failure;
    }

    await file.create(recursive: true);
    await file.writeAsString(authMigrationContent);
    final migrate = File(
      '${workingDirectory.path}/lib/database/migrations/migrate.dart',
    );
    if (!migrate.existsSync()) {
      Console.warn(
        'migrate.dart was not found; register the migration manually.',
      );
      return ExitCode.success;
    }

    var source = await migrate.readAsString();
    final imports = RegExp(r'import .+;').allMatches(source).toList();
    if (imports.isEmpty) {
      Console.warn('No import block was found in migrate.dart.');
      return ExitCode.success;
    }
    source = source.replaceFirst(
      imports.last.group(0)!,
      "${imports.last.group(0)}\nimport '$fileName';",
    );

    final registry = RegExp(
      r'migrationRegister\s*\(\s*\[\s*([\s\S]*?)\s*\]\s*\)',
      multiLine: true,
    );
    final match = registry.firstMatch(source);
    if (match == null) {
      Console.warn('migrationRegister([...]) was not found in migrate.dart.');
      await migrate.writeAsString(source);
      return ExitCode.success;
    }

    final existing = (match.group(1) ?? '').trim().replaceFirst(
      RegExp(r',\s*$'),
      '',
    );
    final entries = [
      if (existing.isNotEmpty) existing,
      'CreatePersonalAccessTokensTable()',
    ].join(',\n      ');
    source = source.replaceFirst(
      registry,
      'migrationRegister([\n      $entries,\n    ])',
    );
    await migrate.writeAsString(source);
    Console.success('Authentication migration created');
    return ExitCode.success;
  }
}
