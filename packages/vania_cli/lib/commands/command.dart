import 'dart:io';

/// Stable process exit codes returned by every CLI command.
abstract final class ExitCode {
  static const int success = 0;
  static const int failure = 1;
  static const int usage = 64;
  static const int noInput = 66;
}

/// One command exposed by the Vania executable.
abstract class Command {
  String get name;

  String get description;

  String get usage => '';

  String get help => '';

  bool get requiresProject => true;

  Directory? _workingDirectory;

  Directory get workingDirectory => _workingDirectory ?? Directory.current;

  set workingDirectory(Directory directory) => _workingDirectory = directory;

  Future<int> execute(List<String> arguments);

  void printUsage() {
    stdout.writeln('Usage: vania $name${usage.isEmpty ? '' : ' $usage'}');
    if (help.isEmpty) return;
    stdout
      ..writeln()
      ..writeln(help);
  }
}
