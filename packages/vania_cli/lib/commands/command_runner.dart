import 'dart:io';

import '../common/console.dart';
import '../common/constants.dart';
import 'auth_command.dart';
import 'build_command.dart';
import 'command.dart';
import 'create_alter_table_migration_command.dart';
import 'create_controller_command.dart';
import 'create_database_seeder_command.dart';
import 'create_mail_command.dart';
import 'create_middleware_command.dart';
import 'create_migration_command.dart';
import 'create_model_command.dart';
import 'create_service_provider_command.dart';
import 'key_generate_command.dart';
import 'migrate_command.dart';
import 'migrate_database_seeder_command.dart';
import 'migrate_fresh_command.dart';
import 'new_project.dart';
import 'route_list_command.dart';
import 'serve_command.dart';
import 'serve_down_command.dart';
import 'terminate_port_command.dart';
import 'update_command.dart';

class CommandRunner {
  CommandRunner({Map<String, Command>? commands, Directory? workingDirectory})
    : _commands = commands ?? defaultCommands(),
      _workingDirectory = workingDirectory;

  final Map<String, Command> _commands;
  final Directory? _workingDirectory;

  Directory get _root => _workingDirectory ?? Directory.current;

  static Map<String, Command> defaultCommands() => {
    'serve': ServeCommand(),
    'create': NewProject(),
    'build': BuildCommand(),
    'down': ServeDownCommand(),
    'db:seed': CreateDatabaseSeederCommand(),
    'key:generate': KeyGenerateCommand(),
    'route:list': RouteListCommand(),
    'make:auth': AuthCommand(),
    'make:controller': CreateControllerCommand(),
    'make:middleware': CreateMiddlewareCommand(),
    'make:migration': CreateMigrationCommand(),
    'make:migration-alter': CreateAlterTableMigrationCommand(),
    'make:model': CreateModelCommand(),
    'make:mail': CreateMailCommand(),
    'make:provider': CreateServiceProviderCommand(),
    'migrate': MigrateCommand(),
    'migrate:seed': MigrateDatabaseSeederCommand(),
    'migrate:fresh': MigrateFreshCommand(
      commandName: 'migrate:fresh',
      flag: '--fresh',
      description: 'Drop all tables and re-run all migrations',
    ),
    'migrate:install': MigrateFreshCommand(
      commandName: 'migrate:install',
      flag: '--install',
      description: 'Create the migration repository',
    ),
    'migrate:refresh': MigrateFreshCommand(
      commandName: 'migrate:refresh',
      flag: '--refresh',
      description: 'Reset and re-run all migrations',
    ),
    'migrate:reset': MigrateFreshCommand(
      commandName: 'migrate:reset',
      flag: '--reset',
      description: 'Rollback all database migrations',
    ),
    'migrate:rollback': MigrateFreshCommand(
      commandName: 'migrate:rollback',
      flag: '--rollback',
      description: 'Rollback the last database migration',
    ),
    'update': UpdateCommand(),
    'terminate-port': TerminateOpenPortCommand(),
  };

  Future<int> run(List<String> arguments) async {
    if (arguments.isEmpty) {
      _printOverview();
      return ExitCode.success;
    }

    final first = arguments.first;
    if (_isVersion(first)) {
      Console.line(
        '${Console.bold('Vania CLI')} ${Console.green(Constants.cliVersion)}',
      );
      return ExitCode.success;
    }
    if (first == 'help' || _isHelp(first)) {
      return _printHelp(arguments.length > 1 ? arguments[1] : null);
    }

    final name = first.toLowerCase();
    final command = _commands[name];
    if (command == null) {
      Console.error('Unknown command: $name');
      final suggestion = _closestMatch(name);
      if (suggestion != null) {
        Console.line('Did you mean ${Console.cyan(suggestion)}?');
      }
      return ExitCode.usage;
    }

    final commandArguments = arguments.sublist(1);
    if (commandArguments.any(_isHelp)) {
      command.printUsage();
      return ExitCode.success;
    }

    command.workingDirectory = _root;
    if (command.requiresProject &&
        !Directory('${_root.path}/lib').existsSync()) {
      Console.error('Run this command from a Vania project root.');
      return ExitCode.noInput;
    }

    try {
      return await command.execute(commandArguments);
    } catch (error, stackTrace) {
      Console.error('$name failed: $error');
      if (Platform.environment['VANIA_CLI_DEBUG'] == '1') {
        Console.line(Console.dim(stackTrace.toString()));
      }
      return ExitCode.failure;
    }
  }

  void _printOverview() {
    Console.line(Console.bold('Vania CLI'));
    Console.line('Usage: vania <command> [arguments]');
    Console.line();
    final width = _commands.keys
        .map((name) => name.length)
        .reduce((left, right) => left > right ? left : right);
    for (final entry in _commands.entries) {
      Console.line(
        '  ${Console.green(entry.key.padRight(width))}  '
        '${entry.value.description}',
      );
    }
    Console.line();
    Console.line(Console.dim('Run "vania help <command>" for details.'));
  }

  int _printHelp(String? name) {
    if (name == null) {
      _printOverview();
      return ExitCode.success;
    }
    final command = _commands[name.toLowerCase()];
    if (command == null) {
      Console.error('Unknown command: $name');
      return ExitCode.usage;
    }
    Console.line(command.description);
    Console.line();
    command.printUsage();
    return ExitCode.success;
  }

  static bool _isVersion(String value) =>
      value == '-v' || value == '-V' || value == '--version';

  static bool _isHelp(String value) => value == '-h' || value == '--help';

  String? _closestMatch(String input) {
    String? closest;
    var shortest = 3;
    for (final name in _commands.keys) {
      final distance = _editDistance(input, name);
      if (distance >= shortest) continue;
      shortest = distance;
      closest = name;
    }
    return closest;
  }

  static int _editDistance(String left, String right) {
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var leftIndex = 0; leftIndex < left.length; leftIndex++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = leftIndex + 1;
      for (var rightIndex = 0; rightIndex < right.length; rightIndex++) {
        final substitution =
            previous[rightIndex] +
            (left[leftIndex] == right[rightIndex] ? 0 : 1);
        final insertion = current[rightIndex] + 1;
        final deletion = previous[rightIndex + 1] + 1;
        current[rightIndex + 1] = [
          substitution,
          insertion,
          deletion,
        ].reduce((a, b) => a < b ? a : b);
      }
      previous = current;
    }
    return previous.last;
  }
}
