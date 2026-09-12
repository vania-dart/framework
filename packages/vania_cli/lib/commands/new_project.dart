import 'dart:io';

import 'package:interact_cli/interact_cli.dart'
    show Confirm, Input, Select, Theme, ValidationError;

import '../common/console.dart';
import '../utils/functions.dart';
import '../utils/process_runner.dart';
import 'command.dart';

class NewProject extends Command {
  @override
  String get name => 'create';

  @override
  String get description => 'Create a new Vania project';

  @override
  String get usage => '<name>';

  @override
  bool get requiresProject => false;

  @override
  Future<int> execute(List<String> arguments) async {
    final projectName = _projectName(arguments);
    if (projectName == null) return ExitCode.usage;

    final kit = _selectStarterKit();
    final initializeGit =
        Confirm(
          prompt: 'Would you like to initialize a Git repository?',
          defaultValue: true,
          waitForNewLine: true,
        ).interact();
    final project = Directory('${workingDirectory.path}/$projectName');
    if (project.existsSync()) {
      Console.error('"$projectName" already exists.');
      return ExitCode.failure;
    }

    Console.info('Creating a Vania project at ./$projectName');
    final cloned = await Process.run('git', [
      'clone',
      '--branch',
      kit.branch,
      'https://github.com/vania-dart/sample.git',
      projectName,
    ], workingDirectory: workingDirectory.path);
    if (cloned.exitCode != 0) {
      Console.error('Could not clone the Vania starter project.');
      Console.line(Console.dim(cloned.stderr.toString().trim()));
      return ExitCode.failure;
    }

    final clonedGit = Directory('${project.path}/.git');
    if (clonedGit.existsSync()) clonedGit.deleteSync(recursive: true);
    _replaceProjectName(project, projectName);

    final vaniaAdded = await runStreaming('dart', const [
      'pub',
      'add',
      'vania',
    ], workingDirectory: project.path);
    if (vaniaAdded != 0) {
      Console.warn('Project created, but adding vania failed.');
      return ExitCode.failure;
    }
    if (kit.needsMongo) {
      final mongoAdded = await runStreaming('dart', const [
        'pub',
        'add',
        'mongo_dart',
      ], workingDirectory: project.path);
      if (mongoAdded != 0) {
        Console.warn('Project created, but adding mongo_dart failed.');
        return ExitCode.failure;
      }
    }
    if (initializeGit) {
      final initialized = await Process.run('git', const [
        'init',
      ], workingDirectory: project.path);
      if (initialized.exitCode != 0) {
        Console.warn('Project created, but git init failed.');
      }
    }

    _configureEnvironment(project, projectName, kit);
    Console.success('Created ${Console.cyan(projectName)}');
    Console.line('Next:');
    Console.line('  cd $projectName');
    Console.line('  vania serve');
    return ExitCode.success;
  }

  String? _projectName(List<String> arguments) {
    if (arguments.length > 1) {
      Console.error('create accepts one project name.');
      return null;
    }
    final value =
        arguments.isEmpty
            ? Input.withTheme(
              theme: Theme.defaultTheme,
              prompt: 'What is the name of your project?',
              validator: (input) {
                if (!_validProjectName.hasMatch(input)) {
                  throw ValidationError('Contains an invalid character.');
                }
                return true;
              },
            ).interact()
            : arguments.single;
    if (!_validProjectName.hasMatch(value)) {
      Console.error(
        'Project names may contain letters, digits, and underscores.',
      );
      return null;
    }
    return pascalToSnake(value);
  }

  _StarterKit _selectStarterKit() {
    final index =
        Select.withTheme(
          theme: Theme.defaultTheme,
          prompt: 'Which starter kit would you like to use? (default: Basic)',
          options: _starterKits.map((kit) => kit.label).toList(),
        ).interact();
    return _starterKits[index];
  }

  void _replaceProjectName(Directory project, String projectName) {
    for (final entity in project.listSync(recursive: true)) {
      if (entity is! File || entity.path.contains('bin/vania')) continue;
      try {
        final source = entity.readAsStringSync();
        entity.writeAsStringSync(
          source.replaceAll('vania_template_project', projectName),
        );
      } on FileSystemException {
        // Binary files are intentionally left untouched.
      }
    }
  }

  void _configureEnvironment(
    Directory project,
    String projectName,
    _StarterKit kit,
  ) {
    final env = File('${project.path}/.env');
    if (!env.existsSync()) return;
    var contents = env
        .readAsStringSync()
        .replaceAll('applicationName', projectName)
        .replaceAll('applicationKey', generateRandomKey());

    final databases = ['None', 'MySQL', 'PostgreSQL', 'SQLite', 'MongoDB'];
    final selected =
        Select.withTheme(
          theme: Theme.defaultTheme,
          prompt: 'Which database will your application use?',
          options: databases,
        ).interact();
    if (selected == 0 || selected == 4 || kit.needsMongo) {
      env.writeAsStringSync(contents);
      return;
    }

    final connection = switch (selected) {
      1 => 'mysql',
      2 => 'pgsql',
      _ => 'sqlite',
    };
    final host = _input('Database address', defaultValue: 'localhost');
    final port = _input('Database port', defaultValue: '3306');
    final database = _input('Database name');
    final username = _input('Database username');
    final password = _input('Database password');
    final block = '''
DB_CONNECTION=$connection
DB_HOST=$host
DB_PORT=$port
DB_NAME=$database
DB_USERNAME=$username
DB_PASSWORD=$password
DB_SSL_MODE=false
DB_POOL=true
DB_POOL_SIZE=2''';
    const marker = 'SESSION_LIFETIME=86400';
    if (contents.contains(marker)) {
      contents = contents.replaceFirst(marker, '$marker\n\n$block');
    } else {
      contents = '$contents\n$block\n';
    }
    env.writeAsStringSync(contents);
  }

  String _input(String prompt, {String? defaultValue}) =>
      Input.withTheme(
        theme: Theme.defaultTheme,
        prompt: prompt,
        defaultValue: defaultValue,
      ).interact();

  static final RegExp _validProjectName = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

  static const List<_StarterKit> _starterKits = [
    _StarterKit(label: 'Basic', branch: 'basic'),
    _StarterKit(label: 'Feature Based', branch: 'feature_based'),
    _StarterKit(label: 'Basic CRUD', branch: 'basic_crud'),
    _StarterKit(label: 'MVC MongoDB', branch: 'mvc_mongodb', needsMongo: true),
  ];
}

class _StarterKit {
  const _StarterKit({
    required this.label,
    required this.branch,
    this.needsMongo = false,
  });

  final String label;
  final String branch;
  final bool needsMongo;
}
