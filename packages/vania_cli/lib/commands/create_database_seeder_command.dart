import 'dart:io';

import 'package:path/path.dart' as path;

import '../common/console.dart';
import '../common/recase.dart';
import '../common/stubs.dart';
import 'command.dart';

class CreateDatabaseSeederCommand extends Command {
  @override
  String get name => 'db:seed';

  @override
  String get description => 'Create and register a database seeder';

  @override
  String get usage => '<name> [--factory <name>] [--force]';

  @override
  Future<int> execute(List<String> arguments) async {
    final options = _SeederOptions.parse(arguments);
    if (options == null) return ExitCode.usage;

    final relativeSeederPath = _seederPath(options.name);
    final seederFile = File('${workingDirectory.path}/$relativeSeederPath');
    if (seederFile.existsSync() && !options.force) {
      Console.error('Seeder already exists at $relativeSeederPath.');
      return ExitCode.failure;
    }

    final className = options.name.split('/').last.pascalCase;
    var factoryImport = '';
    var body = '    // Add the records this seeder owns.';
    final factoryName = options.factory;
    if (factoryName != null) {
      final relativeFactoryPath =
          'lib/database/factory/${factoryName.snakeCase}.dart';
      final factoryFile = File('${workingDirectory.path}/$relativeFactoryPath');
      if (!factoryFile.existsSync()) {
        await factoryFile.create(recursive: true);
        await factoryFile.writeAsString(
          Stubs.factory.replaceAll('FactoryName', factoryName.pascalCase),
        );
        Console.success('Factory created at $relativeFactoryPath');
      }

      final importPath = path
          .relative(factoryFile.path, from: seederFile.parent.path)
          .replaceAll('\\', '/');
      factoryImport = "\nimport '$importPath';\n";
      body =
          '    final records = ${factoryName.pascalCase}().createMany(500);\n'
          '    // Persist records using the model for this seeder.\n'
          '    print(records.length);';
    }

    final source = Stubs.seeder
        .replaceAll('FactoryImport', factoryImport)
        .replaceAll('SeederName', className)
        .replaceAll('SeederBody', body);
    await seederFile.create(recursive: true);
    await seederFile.writeAsString(source);
    await _register(relativeSeederPath, className);
    Console.success('Seeder created at $relativeSeederPath');
    return ExitCode.success;
  }

  String _seederPath(String name) {
    final segments = name.split('/');
    final fileName = segments.removeLast().snakeCase;
    final directory = segments.isEmpty ? '' : '${segments.join('/')}/';
    return 'lib/database/seeders/$directory$fileName.dart';
  }

  Future<void> _register(String relativeSeederPath, String className) async {
    final registry = File(
      '${workingDirectory.path}/lib/database/seeders/database_seeder.dart',
    );
    if (!registry.existsSync()) {
      await registry.create(recursive: true);
      await registry.writeAsString(Stubs.databaseSeeder);
    }

    var source = await registry.readAsString();
    final importPath = path
        .relative(
          '${workingDirectory.path}/$relativeSeederPath',
          from: registry.parent.path,
        )
        .replaceAll('\\', '/');
    final import = "import '$importPath';";
    if (!source.contains(import)) {
      final imports = RegExp(r'import .+;').allMatches(source).toList();
      if (imports.isNotEmpty) {
        source = source.replaceFirst(
          imports.last.group(0)!,
          '${imports.last.group(0)}\n$import',
        );
      } else {
        source = '$import\n$source';
      }
    }

    final list = RegExp(r'seeders:\s*\[\s*([\s\S]*?)\s*\]');
    final match = list.firstMatch(source);
    if (match == null) {
      Console.warn('Could not register $className in database_seeder.dart.');
      await registry.writeAsString(source);
      return;
    }
    final existing = (match.group(1) ?? '').trim().replaceFirst(
      RegExp(r',\s*$'),
      '',
    );
    final constructor = '$className()';
    if (!existing.contains(constructor)) {
      final entries = [
        if (existing.isNotEmpty) existing,
        constructor,
      ].join(',\n      ');
      source = source.replaceFirst(list, 'seeders: [\n      $entries,\n    ]');
    }
    await registry.writeAsString(source);
  }
}

class _SeederOptions {
  const _SeederOptions({required this.name, required this.force, this.factory});

  final String name;
  final String? factory;
  final bool force;

  static final RegExp _namePattern = RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*(?:/[A-Za-z][A-Za-z0-9_]*)*$',
  );
  static final RegExp _factoryPattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

  static _SeederOptions? parse(List<String> arguments) {
    final values = List<String>.from(arguments);
    var force = false;
    String? factory;
    String? name;

    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == '--force') {
        force = true;
        continue;
      }
      if (value == '--factory') {
        if (index + 1 >= values.length) {
          Console.error('--factory needs a value.');
          return null;
        }
        factory = values[++index];
        continue;
      }
      if (value.startsWith('-') || name != null) {
        Console.error('Unexpected argument: $value');
        return null;
      }
      name = value;
    }

    if (name == null) {
      if (!stdin.hasTerminal) {
        Console.error('A seeder name is required.');
        return null;
      }
      Console.line('What should the seeder be named?');
      stdout.write('${Console.bold('>')} ');
      name = stdin.readLineSync()?.trim();
    }
    if (name == null || !_namePattern.hasMatch(name)) {
      Console.error('Seeder names contain invalid characters.');
      return null;
    }
    if (factory != null && !_factoryPattern.hasMatch(factory)) {
      Console.error('Factory names contain invalid characters.');
      return null;
    }
    return _SeederOptions(name: name, factory: factory, force: force);
  }
}
