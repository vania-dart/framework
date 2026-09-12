library;

import 'package:test/test.dart';
import 'package:vania/database.dart';
import 'package:vania/foundation.dart' show DatabaseException, Env;

class RecordingConnection implements DatabaseConnection {
  final List<String> executed = [];
  final List<String> selected = [];

  final List<String> history = [];

  @override
  Future<void> connect() async {}

  @override
  Future<void> close() async {}

  @override
  Future<bool> execute(String q, [Map<String, dynamic> b = const {}]) async {
    executed.add(q);
    final insert = RegExp(r"INSERT INTO .*VALUES \('([^']+)'").firstMatch(q);
    if (insert != null) history.insert(0, insert.group(1)!);
    final delete = RegExp(r"DELETE FROM .*=\s*'([^']+)'").firstMatch(q);
    if (delete != null) history.remove(delete.group(1)!);
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> select(
    String q, [
    Map<String, dynamic> b = const {},
  ]) async {
    selected.add(q);
    if (q.contains('max_batch')) {
      return [
        {'max_batch': history.isEmpty ? 0 : 1},
      ];
    }
    final where = RegExp("""migration"?\\s*=\\s*'([^']+)'""").firstMatch(q);
    if (where != null) {
      return history.contains(where.group(1))
          ? [
              {'id': 1},
            ]
          : [];
    }
    final rows = history.map((m) => {'migration': m}).toList();
    final limit = RegExp(r'LIMIT (\d+)').firstMatch(q);
    if (limit != null) return rows.take(int.parse(limit.group(1)!)).toList();
    return rows;
  }

  @override
  Future<dynamic> insert(String q, [Map<String, dynamic> b = const {}]) async =>
      0;

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}

final List<String> events = [];

class CreateUsersTable extends Migration {
  @override
  Future<void> up() async {
    events.add('up:users');
    await create('users', (table) {
      table.id();
      table.string('email');
    });
  }

  @override
  Future<void> down() async {
    events.add('down:users');
    await drop('users');
  }
}

class CreatePostsTable extends Migration {
  @override
  Future<void> up() async {
    events.add('up:posts');
    await create('posts', (table) {
      table.id();
      table.string('title');
    });
  }

  @override
  Future<void> down() async {
    events.add('down:posts');
    await drop('posts');
  }
}

class CreateTwoTables extends Migration {
  @override
  Future<void> up() async {
    await create('alpha', (table) => table.string('alpha_col'));
    await create('beta', (table) => table.string('beta_col'));
  }

  @override
  Future<void> down() async {}
}

late RecordingConnection connection;

Future<void> setupMigrationConnection() async {
  connection = RecordingConnection();
  DatabaseConnectionFactory.debugClear();
  DatabaseConnectionFactory.register('sqlite', (_) => connection);
  await MigrationConnection().setup({
    'default': 'sqlite',
    'connections': {
      'sqlite': {'driver': 'sqlite', 'database': ':memory:', 'pool': true},
    },
  });
  connection.executed.clear();
}

void main() {
  setUpAll(() => Env().env['APP_ENV'] = 'local');

  setUp(() async {
    events.clear();
    await setupMigrationConnection();
  });

  tearDown(() async {
    await MigrationConnection().closeConnection();
    DatabaseConnectionFactory.debugClear();
  });

  group('Migration adapter resolution', () {
    test('resolves the adapter lazily, not at construction time', () async {
      await MigrationConnection().closeConnection();
      final migration = CreateUsersTable();
      await setupMigrationConnection();

      await migration.up();

      expect(
        connection.executed.any((q) => q.startsWith('CREATE TABLE "users"')),
        isTrue,
      );
    });

    test(
      'throws instead of silently skipping when setup() never ran',
      () async {
        await MigrationConnection().closeConnection();
        final migration = CreateUsersTable();

        expect(migration.up(), throwsA(isA<DatabaseException>()));
      },
    );

    test('create() emits CREATE TABLE, never DROP TABLE', () async {
      await CreateUsersTable().up();

      expect(connection.executed.single, startsWith('CREATE TABLE "users"'));
      expect(connection.executed.single, isNot(contains('DROP')));
    });
  });

  group('Migration schema builder isolation', () {
    test('two create() calls do not leak columns into each other', () async {
      await CreateTwoTables().up();

      final alpha = connection.executed[0];
      final beta = connection.executed[1];
      expect(alpha, contains('"alpha_col"'));
      expect(alpha, isNot(contains('"beta_col"')));
      expect(beta, contains('"beta_col"'));
      expect(beta, isNot(contains('"alpha_col"')));
    });
  });

  group('TableDefinition execution', () {
    test('runs once even when several Future members are used', () async {
      final migration = CreateUsersTable();
      final definition = migration.create('users', (table) => table.id());

      await definition.whenComplete(() {});
      await definition;
      await definition.then((_) {});

      expect(
        connection.executed.where((q) => q.startsWith('CREATE TABLE')),
        hasLength(1),
      );
    });

    test('applies table options through the adapter', () async {
      final migration = CreateUsersTable();

      // SQLite has no table-level options, so the adapter drops them rather
      // than emitting mangled MySQL syntax.
      await migration
          .create('users', (table) => table.id())
          .engine('InnoDB')
          .comment("o'hara");

      expect(connection.executed, hasLength(1));
      expect(connection.executed.single, startsWith('CREATE TABLE'));
    });
  });

  group('Migration.execute', () {
    test('sends raw SQL through untouched', () async {
      final migration = CreateUsersTable();
      const sql = "INSERT INTO t (a) VALUES ('two  spaces and `tick`')";

      await migration.execute(sql);

      expect(connection.executed.single, sql);
    });

    test('executeAdapted still translates dialect', () async {
      final migration = CreateUsersTable();

      await migration.executeAdapted('CREATE TABLE `t` (`a` VARCHAR(10))');

      expect(connection.executed.single, contains('"t"'));
      expect(connection.executed.single, isNot(contains('`')));
    });
  });

  group('MigrationRunner registration', () {
    test('rejects duplicate migration names', () {
      expect(
        () => MigrationRunner().migrationRegister([
          CreateUsersTable(),
          CreateUsersTable(),
        ]),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('MigrationRunner argument parsing', () {
    test('throws when --steps is the last argument', () {
      final runner = MigrationRunner().migrationRegister([CreateUsersTable()]);

      expect(
        runner.run(['--rollback', '--steps']),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('throws when --steps is not a positive integer', () {
      final runner = MigrationRunner().migrationRegister([CreateUsersTable()]);

      expect(
        runner.run(['--rollback', '--steps', 'abc']),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('MigrationRunner environment guard', () {
    tearDown(() => Env().env['APP_ENV'] = 'local');

    test('refuses to migrate a production database', () async {
      Env().env['APP_ENV'] = 'production';
      final runner = MigrationRunner().migrationRegister([CreateUsersTable()]);

      await expectLater(runner.run([]), throwsA(isA<DatabaseException>()));
      expect(events, isEmpty);
    });

    test('migrates production when --force is passed', () async {
      Env().env['APP_ENV'] = 'production';
      final runner = MigrationRunner().migrationRegister([CreateUsersTable()]);

      await runner.run(['--force']);

      expect(events, ['up:users']);
    });
  });

  group('MigrationRunner rollback ordering', () {
    test('--fresh rolls back in reverse registration order', () async {
      await MigrationRunner()
          .migrationRegister([CreateUsersTable(), CreatePostsTable()])
          .run(['--fresh']);

      expect(events, ['down:posts', 'down:users', 'up:users', 'up:posts']);
    });
  });

  group('MigrationRunner history integrity', () {
    test('refuses to drop history rows for unregistered migrations', () async {
      connection.history.add('create_orphan_table');

      expect(
        MigrationRunner().migrationRegister([CreateUsersTable()]).run([
          '--reset',
        ]),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('reset rolls back and clears every registered migration', () async {
      final runner = MigrationRunner().migrationRegister([
        CreateUsersTable(),
        CreatePostsTable(),
      ]);
      await runner.run([]);
      expect(connection.history, hasLength(2));

      events.clear();
      await runner.run(['--reset']);

      expect(events, ['down:posts', 'down:users']);
      expect(connection.history, isEmpty);
    });
  });

  group('MigrationRunner failure reporting', () {
    test('surfaces the cause when a migration fails', () async {
      await MigrationConnection().closeConnection();
      final migration = CreateUsersTable();

      await expectLater(
        MigrationRunner().migrationRegister([migration]).run([]),
        throwsA(
          isA<DatabaseException>().having(
            (e) => e.message,
            'message',
            contains('Database connection not established'),
          ),
        ),
      );
    });
  });

  group('MigrationConnection.setup validation', () {
    test('rejects a config without a default connection', () async {
      await MigrationConnection().closeConnection();

      expect(
        MigrationConnection().setup(const {}),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('rejects a default that has no matching connection entry', () async {
      await MigrationConnection().closeConnection();

      expect(
        MigrationConnection().setup({
          'default': 'mysql',
          'connections': <String, dynamic>{},
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('Migration history table name', () {
    test('uses the adapter migrationsTable for tracking queries', () async {
      await MigrationRunner().migrationRegister([CreateUsersTable()]).run([]);

      expect(
        connection.selected.every((q) => q.contains('"migrations"')),
        isTrue,
      );
    });
  });
}
