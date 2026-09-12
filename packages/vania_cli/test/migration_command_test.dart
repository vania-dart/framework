import 'dart:io';

import 'package:test/test.dart';
import 'package:vania_cli/vania_cli.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('vania_cli_migration_');
    await Directory('${project.path}/lib').create();
  });

  tearDown(() => project.delete(recursive: true));

  test(
    'uses the plural table from a conventional migration name exactly',
    () async {
      final command = CreateMigrationCommand()..workingDirectory = project;

      expect(await command.execute(['create_posts_table']), ExitCode.success);

      final migration =
          File(
            '${project.path}/lib/database/migrations/create_posts_table.dart',
          ).readAsStringSync();
      expect(migration, contains("create('posts'"));
      expect(migration, contains("drop('posts')"));
      expect(migration, isNot(contains('postses')));
    },
  );

  test(
    'registers repeated invocations without leaking mutable template state',
    () async {
      final first = CreateMigrationCommand()..workingDirectory = project;
      final second = CreateMigrationCommand()..workingDirectory = project;

      await first.execute(['create_posts_table']);
      await second.execute(['create_comments_table']);

      final runner =
          File(
            '${project.path}/lib/database/migrations/migrate.dart',
          ).readAsStringSync();
      expect(runner, contains("import 'create_posts_table.dart';"));
      expect(runner, contains("import 'create_comments_table.dart';"));
      expect(runner, contains('CreatePostsTable()'));
      expect(runner, contains('CreateCommentsTable()'));
    },
  );

  test('alter migration targets the supplied v2 table name', () async {
    final command =
        CreateAlterTableMigrationCommand()..workingDirectory = project;

    expect(
      await command.execute(['add_status_to_users', 'users']),
      ExitCode.success,
    );

    final migration =
        File(
          '${project.path}/lib/database/migrations/add_status_to_users.dart',
        ).readAsStringSync();
    expect(migration, contains("alterColumn('users'"));
    expect(migration, isNot(contains('userses')));
  });
}
