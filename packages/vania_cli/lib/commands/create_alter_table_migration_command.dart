import 'dart:io';

import 'package:interact_cli/interact_cli.dart';
import 'package:vania_cli/common/recase.dart';
import 'package:vania_cli/utils/functions.dart';

import '../common/console.dart';
import 'command.dart';

const String _alterMigrationStub = '''
import 'package:vania/migration.dart';

class MigrationALterNameClass extends Migration {
  @override
  Future<void> up() async {
    await alterColumn('TableName', (Schema table) {
      
    },afterColumn: 'email');
  }

  
  @override
  Future<void> down() async {}
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

class CreateAlterTableMigrationCommand extends Command {
  @override
  String get name => 'make:migration-alter';

  @override
  String get description =>
      'Create a new alter table migration file. This command allows you to add a new column to an existing table or alter an existing column';

  String _readMigrationName() {
    return Input.withTheme(
      theme: Theme.defaultTheme,
      prompt: 'What should the migration be named?',
      validator: (x) {
        if (!RegExp(r'^[A-Za-z][A-Za-z_]*$').hasMatch(x)) {
          throw ValidationError(
            'Migration must contain only letters a-z and optional _',
          );
        }
        if (x.isEmpty) {
          throw ValidationError('Select a name for your migration file');
        }
        return true;
      },
    ).interact();
  }

  String _readTableName() {
    return Input.withTheme(
      theme: Theme.defaultTheme,
      prompt: 'To which table should this column be added?',
      validator: (x) {
        if (x.isEmpty) {
          throw ValidationError(
            'Specify to which table you want to add the column (fill in the table name)',
          );
        }
        return true;
      },
    ).interact();
  }

  @override
  Future<int> execute(List<String> arguments) async {
    if (arguments.isEmpty) {
      arguments.add(_readMigrationName());
    }

    String migrationName = arguments[0].toLowerCase();

    if (!RegExp(r'^[A-Za-z][A-Za-z_]*$').hasMatch(migrationName)) {
      Console.error(
        'Migration names may only contain letters and underscores.',
      );
      return ExitCode.usage;
    }

    if (arguments.length < 2) {
      arguments.add(_readTableName());
    }

    final tableName = arguments[1].toLowerCase();

    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(tableName)) {
      Console.error(
        'Table names may only contain letters, digits, and underscores.',
      );
      return ExitCode.usage;
    }

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

    String str = _alterMigrationStub
        .replaceFirst('MigrationALterNameClass', snakeToPascal(migrationName))
        .replaceFirst('TableName', tableName);

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

    var importMatch = importRegExp.allMatches(migrateSource);
    if (importMatch.isNotEmpty) {
      migrateSource = migrateSource.replaceFirst(
        importMatch.last.group(0).toString(),
        "${importMatch.last.group(0)}\nimport '${pascalToSnake(migrationName)}.dart';",
      );
    }

    Match? migrationRegisterMatch = migrationRegisterRegex.firstMatch(
      migrateSource,
    );

    if (migrationRegisterMatch != null) {
      String existingMigrations = migrationRegisterMatch.group(1)?.trim() ?? '';
      String newMigrations;

      if (existingMigrations.isEmpty) {
        newMigrations = '${migrationName.pascalCase}()';
      } else {
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

    migrate.writeAsStringSync(migrateSource);

    stdout.writeln(
      ' \x1B[44m\x1B[37m INFO \x1B[0m Migration [$filePath] created successfully.',
    );
    return ExitCode.success;
  }
}
