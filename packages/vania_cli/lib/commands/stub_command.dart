import 'dart:io';

import '../common/console.dart';
import 'command.dart';

/// Shared, safe file creation workflow for simple `make:` commands.
abstract class StubCommand extends Command {
  String get label;

  String pathFor(String name);

  String render(String name, List<String> arguments);

  @override
  String get usage => '<name> [--force]';

  @override
  String get help => '''
Creates a new ${label.toLowerCase()}.

Options:
  --force   overwrite an existing file''';

  static final RegExp _validName = RegExp(
    r'^[a-zA-Z][a-zA-Z0-9_]*(?:/[a-zA-Z][a-zA-Z0-9_]*)*$',
  );

  @override
  Future<int> execute(List<String> arguments) async {
    final parsed = _parse(arguments);
    if (parsed == null) return ExitCode.usage;

    final relativePath = pathFor(parsed.name);
    final file = File('${workingDirectory.path}/$relativePath');
    if (file.existsSync() && !parsed.force) {
      Console.error('$label already exists at $relativePath.');
      Console.line(Console.dim('Pass --force to overwrite it.'));
      return ExitCode.failure;
    }

    await file.create(recursive: true);
    await file.writeAsString(render(parsed.name, [parsed.name]));
    Console.success('$label created at ${Console.cyan(relativePath)}');
    return ExitCode.success;
  }

  _StubArguments? _parse(List<String> arguments) {
    final values = List<String>.from(arguments);
    final force = values.remove('--force');

    for (final value in values) {
      if (!value.startsWith('-')) continue;
      Console.error('Unknown option: $value');
      return null;
    }
    if (values.length > 1) {
      Console.error('Too many arguments for $name.');
      return null;
    }

    final stubName = values.isEmpty ? _promptForName() : values.single;
    if (stubName == null || stubName.isEmpty) {
      Console.error('A ${label.toLowerCase()} name is required.');
      return null;
    }
    if (!_validName.hasMatch(stubName)) {
      Console.error(
        '$label names must start with a letter. Each path segment may only '
        'contain letters, digits, and underscores.',
      );
      return null;
    }

    return _StubArguments(name: stubName, force: force);
  }

  String? _promptForName() {
    if (!stdin.hasTerminal) return null;
    Console.line('What should the ${label.toLowerCase()} be named?');
    stdout.write('${Console.bold('>')} ');
    return stdin.readLineSync()?.trim();
  }
}

class _StubArguments {
  const _StubArguments({required this.name, required this.force});

  final String name;
  final bool force;
}
