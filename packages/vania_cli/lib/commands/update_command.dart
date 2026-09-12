import '../common/console.dart';
import '../utils/process_runner.dart';
import 'command.dart';

class UpdateCommand extends Command {
  @override
  String get name => 'update';

  @override
  String get description => 'Update Vania CLI to the latest version';

  @override
  bool get requiresProject => false;

  @override
  Future<int> execute(List<String> arguments) async {
    if (arguments.isNotEmpty) {
      Console.error('update does not accept arguments.');
      return ExitCode.usage;
    }
    Console.info('Updating vania_cli…');
    final code = await runStreaming('dart', const [
      'pub',
      'global',
      'activate',
      'vania_cli',
    ]);
    if (code != 0) {
      Console.error('Update failed.');
      return ExitCode.failure;
    }
    Console.success('Updated');
    return ExitCode.success;
  }
}
