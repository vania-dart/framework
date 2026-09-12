import 'dart:io';

import '../common/console.dart';
import 'command.dart';

class TerminateOpenPortCommand extends Command {
  @override
  String get name => 'terminate-port';

  @override
  String get description => 'Terminate the process listening on APP_PORT';

  @override
  String get usage => '[port]';

  @override
  Future<int> execute(List<String> arguments) async {
    if (arguments.length > 1) {
      Console.error('terminate-port accepts at most one port.');
      return ExitCode.usage;
    }
    final explicit = arguments.isEmpty ? null : int.tryParse(arguments.single);
    if (arguments.isNotEmpty && explicit == null) {
      Console.error('Port must be an integer.');
      return ExitCode.usage;
    }

    final port = explicit ?? _portFromEnv() ?? 8000;
    final success = await runCommand(port);
    if (!success) return ExitCode.failure;
    Console.success('Port $port is available');
    return ExitCode.success;
  }

  Future<bool> runCommand([int? port]) async {
    final resolvedPort = port ?? _portFromEnv() ?? 8000;
    if (Platform.isWindows) return _killOnWindows(resolvedPort);
    if (Platform.isLinux || Platform.isMacOS) {
      return _killOnUnix(resolvedPort);
    }
    Console.error('This platform is not supported.');
    return false;
  }

  int? _portFromEnv() {
    final file = File('${workingDirectory.path}/.env');
    if (!file.existsSync()) return null;
    for (final line in file.readAsLinesSync()) {
      final match = RegExp(r'^\s*APP_PORT\s*=\s*(\d+)\s*$').firstMatch(line);
      if (match != null) return int.tryParse(match.group(1)!);
    }
    return null;
  }

  Future<bool> _killOnWindows(int port) async {
    final result = await Process.run('netstat', const ['-ano']);
    if (result.exitCode != 0) {
      Console.error('netstat failed: ${result.stderr}');
      return false;
    }
    for (final line in result.stdout.toString().split('\n')) {
      if (!line.contains(':$port')) continue;
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 5) continue;
      final killed = await Process.run('taskkill', ['/PID', parts.last, '/F']);
      return killed.exitCode == 0;
    }
    return true;
  }

  Future<bool> _killOnUnix(int port) async {
    final result = await Process.run('lsof', ['-t', '-i', ':$port']);
    if (result.exitCode != 0) return true;
    final pids = result.stdout
        .toString()
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    for (final pid in pids) {
      final killed = await Process.run('kill', ['-TERM', pid]);
      if (killed.exitCode != 0) return false;
    }
    return true;
  }
}
