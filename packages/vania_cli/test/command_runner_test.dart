import 'dart:io';

import 'package:test/test.dart';
import 'package:vania_cli/vania_cli.dart';

class _Recorder extends Command {
  _Recorder({this.exitWith = ExitCode.success, this.needsProject = true});

  final int exitWith;
  final bool needsProject;
  List<String>? received;

  @override
  String get name => 'recorder';

  @override
  String get description => 'Records its arguments';

  @override
  bool get requiresProject => needsProject;

  @override
  Future<int> execute(List<String> arguments) async {
    received = arguments;
    return exitWith;
  }
}

class _ThrowingCommand extends Command {
  @override
  String get name => 'boom';

  @override
  String get description => 'Throws an exception';

  @override
  bool get requiresProject => false;

  @override
  Future<int> execute(List<String> arguments) => throw StateError('boom');
}

void main() {
  group('CommandRunner dispatch', () {
    test('reports the v3 CLI version without needing a project', () async {
      final runner = CommandRunner(commands: {'recorder': _Recorder()});

      expect(await runner.run(['--version']), ExitCode.success);
    });

    test(
      'passes arguments through and returns the command exit code',
      () async {
        final command = _Recorder(
          exitWith: ExitCode.failure,
          needsProject: false,
        );
        final runner = CommandRunner(commands: {'recorder': command});

        final result = await runner.run(['RECORDER', 'one', 'two']);

        expect(result, ExitCode.failure);
        expect(command.received, ['one', 'two']);
      },
    );

    test('returns usage for an unknown command', () async {
      final runner = CommandRunner(commands: {'recorder': _Recorder()});

      expect(await runner.run(['missing']), ExitCode.usage);
    });

    test('turns an unhandled command exception into failure', () async {
      final runner = CommandRunner(commands: {'boom': _ThrowingCommand()});

      expect(await runner.run(['boom']), ExitCode.failure);
    });
  });

  group('CommandRunner project guard', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('vania_cli_runner_');
    });

    tearDown(() => root.delete(recursive: true));

    test('does not run project commands outside a Vania project', () async {
      final command = _Recorder();
      final runner = CommandRunner(
        commands: {'recorder': command},
        workingDirectory: root,
      );

      expect(await runner.run(['recorder']), ExitCode.noInput);
      expect(command.received, isNull);
    });

    test('runs project commands when lib exists', () async {
      await Directory('${root.path}/lib').create();
      final command = _Recorder();
      final runner = CommandRunner(
        commands: {'recorder': command},
        workingDirectory: root,
      );

      expect(await runner.run(['recorder']), ExitCode.success);
      expect(command.received, isEmpty);
      expect(command.workingDirectory.path, root.path);
    });
  });

  group('shipped commands', () {
    final commands = CommandRunner.defaultCommands();

    test('map keys agree with each command name', () {
      commands.forEach((name, command) {
        expect(command.name, name, reason: '$name is registered incorrectly');
      });
    });

    test('keeps v2 commands and includes v3 commands', () {
      expect(
        commands.keys,
        containsAll(<String>[
          'make:migration-alter',
          'terminate-port',
          'migrate:rollback',
          'route:list',
          'key:generate',
        ]),
      );
    });
  });
}
