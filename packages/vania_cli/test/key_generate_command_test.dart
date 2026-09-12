import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania_cli/vania_cli.dart';

void main() {
  late Directory project;
  late KeyGenerateCommand command;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('vania_cli_key_');
    await Directory('${project.path}/lib').create();
    command = KeyGenerateCommand()..workingDirectory = project;
  });

  tearDown(() => project.delete(recursive: true));

  test(
    'writes a cryptographically sized APP_KEY to the project .env',
    () async {
      final env = File('${project.path}/.env')
        ..writeAsStringSync('APP_ENV=local\n');

      expect(await command.execute([]), ExitCode.success);

      final key = env
          .readAsLinesSync()
          .singleWhere((line) => line.startsWith('APP_KEY='))
          .substring('APP_KEY='.length);
      expect(base64Url.decode(key), hasLength(32));
    },
  );

  test('does not replace an existing key without --force', () async {
    final env = File('${project.path}/.env')
      ..writeAsStringSync('APP_KEY=existing\n');

    expect(await command.execute([]), ExitCode.success);
    expect(env.readAsStringSync(), 'APP_KEY=existing\n');

    expect(await command.execute(['--force']), ExitCode.success);
    expect(env.readAsStringSync(), isNot(contains('APP_KEY=existing')));
  });

  test('returns noInput when .env does not exist', () async {
    expect(await command.execute([]), ExitCode.noInput);
  });
}
