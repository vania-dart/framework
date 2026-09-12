import 'dart:io';

import 'package:vania_cli/common/recase.dart';
import 'package:vania_cli/utils/functions.dart';

import 'command.dart';

const String _migrationStub = '''
import 'package:vania/migration.dart';

class MigrationName extends Migration {
  @override
  Future<void> up() async {
    await create('TableName', (Schema table) {
      table.id();
      table.timeStamps();
    });
  }

  @override
  Future<void> down() async {
    await drop('DropTableName');
  }
}
''';

const String _newMigrateFileContents = '''
import 'dart:io';
import 'package:vania/database/database.dart';
import '../../config/database.dart';

void main(List<String> args) async {
  try {
    await MigrationConnection().setup(database);
    await MigrationRunner().migrationRegister([

    ]).run(args);
    await MigrationConnection().connection?.close();
  } catch (e) {
    print('Migration failed: \$e');
    exit(0);
  } finally {
    exit(0);
  }
}
''';

class CreateMigrationCommand extends Command {
  @override
  String get name => 'make:migration';

  @override
  String get description => 'Create a new migration file';

  @override
  Future<int> execute(List<String> arguments) async {
    if (arguments.isEmpty) {
      stdout.writeln('  What should the migration be named?');
      stdout.writeln('\x1B[1m > \x1B[0m');
      final answer = stdin.readLineSync()?.trim();
      if (answer == null || answer.isEmpty) return ExitCode.usage;
      arguments.add(answer);
    }

    RegExp alphaRegex = RegExp(r'^[A-Za-z][A-Za-z_]*$');

    if (!alphaRegex.hasMatch(arguments[0])) {
      stdout.writeln(
        ' \x1B[41m\x1B[37m ERROR \x1B[0m Migration must contain only letters a-z and optional _',
      );
      return ExitCode.usage;
    }

    String migrationName = arguments[0].toLowerCase();

    String filePath =
        '${workingDirectory.path}/lib/database/migrations/${pascalToSnake(migrationName)}.dart';
    File newFile = File(filePath);

    if (newFile.existsSync()) {
      stdout.writeln(
        ' \x1B[41m\x1B[37m ERROR \x1B[0m Migration already exists.',
      );
      return ExitCode.failure;
    }

    await newFile.create(recursive: true);

    final tableName =
        migrationName
            .replaceFirst(RegExp(r'^create_'), '')
            .replaceFirst(RegExp(r'_table$'), '')
            .toLowerCase();
    String str = _migrationStub
        .replaceFirst('MigrationName', snakeToPascal(migrationName))
        .replaceFirst('TableName', tableName)
        .replaceFirst('DropTableName', tableName);

    await newFile.writeAsString(str);

    File migrate = File(
      '${workingDirectory.path}/lib/database/migrations/migrate.dart',
    );

    var migrateSource = _newMigrateFileContents;
    if (migrate.existsSync()) {
      migrateSource = migrate.readAsStringSync();
    }

    final importRegExp = RegExp(r'import .+;');
    final migrationRegisterRegex = RegExp(
      r'migrationRegister\s*\(\s*\[\s*([\s\S]*?)\s*\]\s*\)',
      multiLine: true,
    );

    // Find import statement and append new import
    var importMatch = importRegExp.allMatches(migrateSource);
    if (importMatch.isNotEmpty) {
      migrateSource = migrateSource.replaceFirst(
        importMatch.last.group(0).toString(),
        "${importMatch.last.group(0)}\nimport '${pascalToSnake(migrationName)}.dart';",
      );
    }

    // Find migrationRegister array and replace with modified version
    Match? migrationRegisterMatch = migrationRegisterRegex.firstMatch(
      migrateSource,
    );

    if (migrationRegisterMatch != null) {
      String existingMigrations = migrationRegisterMatch.group(1)?.trim() ?? '';
      String newMigrations;

      if (existingMigrations.isEmpty) {
        newMigrations = '${migrationName.pascalCase}()';
      } else {
        // Remove trailing comma if exists
        existingMigrations = existingMigrations.replaceAll(
          RegExp(r',\s*$'),
          '',
        );
        newMigrations =
            '$existingMigrations,\n      ${migrationName.pascalCase}()';
      }

      migrateSource = migrateSource.replaceAll(
        migrationRegisterRegex,
        'migrationRegister([\n      $newMigrations,\n    ])',
      );
    }

    // Write modified content back to file
    migrate.writeAsStringSync(migrateSource);

    stdout.writeln(
      ' \x1B[44m\x1B[37m INFO \x1B[0m Migration [$filePath] created successfully.',
    );
    return ExitCode.success;
  }
}
