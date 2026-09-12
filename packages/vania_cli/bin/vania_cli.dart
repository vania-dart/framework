import 'dart:io';

import 'package:vania_cli/commands/command_runner.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await CommandRunner().run(arguments);
}
