import 'dart:io';

import 'package:test/test.dart';
import 'package:vania_cli/vania_cli.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('vania_cli_seeder_');
    await Directory('${project.path}/lib').create();
  });

  tearDown(() => project.delete(recursive: true));

  test(
    'creates a nested seeder, factory, and valid registry imports',
    () async {
      final command = CreateDatabaseSeederCommand()..workingDirectory = project;

      expect(
        await command.execute(['admin/UserSeeder', '--factory', 'UserFactory']),
        ExitCode.success,
      );

      final seeder =
          File(
            '${project.path}/lib/database/seeders/admin/user_seeder.dart',
          ).readAsStringSync();
      expect(seeder, contains("import '../../factory/user_factory.dart';"));
      expect(seeder, contains('class UserSeeder extends Seeder'));
      expect(seeder, isNot(contains('SeederName')));

      final registry =
          File(
            '${project.path}/lib/database/seeders/database_seeder.dart',
          ).readAsStringSync();
      expect(registry, contains("import 'admin/user_seeder.dart';"));
      expect(registry, contains('UserSeeder()'));
    },
  );

  test('rejects traversal and an invalid factory path', () async {
    final command = CreateDatabaseSeederCommand()..workingDirectory = project;

    expect(await command.execute(['../Escape']), ExitCode.usage);
    expect(
      await command.execute(['Users', '--factory', '../Escape']),
      ExitCode.usage,
    );
  });
}
