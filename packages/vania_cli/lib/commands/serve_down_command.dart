import 'dart:io';

import '../common/console.dart';
import '../utils/functions.dart';
import 'command.dart';

class ServeDownCommand extends Command {
  @override
  String get name => 'down';

  @override
  String get description => 'Stop the running application';

  @override
  Future<int> execute(List<String> arguments) async {
    final config = await getDartToolVaniaConfig(
      workingDirectory: workingDirectory,
    );
    final recordedPid = config?['process']?['pid'];
    final pid = recordedPid is int ? recordedPid : int.tryParse('$recordedPid');
    if (config == null || pid == null) {
      Console.info('No running server was recorded.');
      return ExitCode.success;
    }

    if (!Process.killPid(pid, ProcessSignal.sigterm)) {
      Console.warn('Process $pid is not running; clearing its record.');
    }
    config.remove('process');
    await updateDartToolVaniaConfig(config, workingDirectory: workingDirectory);
    Console.success('Server stopped');
    return ExitCode.success;
  }
}
