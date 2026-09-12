import 'package:test/test.dart';
import 'package:vania/database.dart';
import 'package:vania/foundation.dart'
    show DatabaseException, Env, QueryException;

class _UserFactory extends SeederFactory {
  @override
  Map<String, dynamic> definition() => {
    'name': 'default name',
    'email': 'default@example.com',
    'active': true,
  };
}

class _RecordingConnection implements DatabaseConnection {
  bool closed = false;

  @override
  Future<void> connect() async {}

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<bool> execute(String q, [Map<String, dynamic> b = const {}]) async =>
      true;

  @override
  Future<List<Map<String, dynamic>>> select(
    String q, [
    Map<String, dynamic> b = const {},
  ]) async => const [];

  @override
  Future<dynamic> insert(String q, [Map<String, dynamic> b = const {}]) async =>
      0;

  @override
  Future<T> transaction<T>(Future<T> Function() action) => action();
}

class _RecordingSeeder extends Seeder {
  bool ran = false;

  @override
  Future<void> run() async {
    ran = true;
  }
}

class _FailingSeeder extends Seeder {
  @override
  Future<void> run() async {
    throw QueryException('boom');
  }
}

void main() {
  // Seeding is refused on staging/production, so the fake deployment these
  // tests run against has to look local.
  setUpAll(() => Env().env['APP_ENV'] = 'local');

  group('SeederFactory.make', () {
    test('applies attribute overrides on top of the definition', () {
      final data = _UserFactory().make({'email': 'override@example.com'});

      expect(data['email'], 'override@example.com');
      expect(data['name'], 'default name');
      expect(data['active'], true);
    });

    test('adds attributes that are absent from the definition', () {
      final data = _UserFactory().make({'role': 'admin'});

      expect(data['role'], 'admin');
      expect(data['name'], 'default name');
    });

    test('returns the plain definition when no attributes are given', () {
      expect(_UserFactory().make(), _UserFactory().definition());
    });

    test('makeMany applies the overrides to every row', () {
      final rows = _UserFactory().makeMany(3, {'name': 'shared'});

      expect(rows, hasLength(3));
      expect(rows.every((r) => r['name'] == 'shared'), isTrue);
    });
  });

  group('SeederFactory.randomElement', () {
    test('throws on an empty list instead of killing the process', () {
      expect(
        () => _UserFactory().randomElement<String>([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns a member of a non-empty list', () {
      expect(_UserFactory().randomElement(['a', 'b']), anyOf('a', 'b'));
    });
  });

  group('SeederRunner.setup', () {
    late _RecordingConnection connection;

    Map<String, dynamic> config() => {
      'default': 'sqlite',
      'connections': {
        'sqlite': {'driver': 'sqlite', 'database': ':memory:'},
      },
    };

    setUp(() {
      connection = _RecordingConnection();
      DatabaseConnectionFactory.debugClear();
      DatabaseConnectionFactory.register('sqlite', (_) => connection);
    });

    tearDown(DatabaseConnectionFactory.debugClear);

    test('runs every seeder and closes the connection', () async {
      final seeders = [_RecordingSeeder(), _RecordingSeeder()];

      await SeederRunner().setup(database: config(), seeders: seeders);

      expect(seeders.every((s) => s.ran), isTrue);
      expect(connection.closed, isTrue);
    });

    test('rejects a config without a default connection', () {
      expect(
        SeederRunner().setup(database: const {}, seeders: []),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('rejects a default that has no matching connection entry', () {
      expect(
        SeederRunner().setup(
          database: {'default': 'mysql', 'connections': <String, dynamic>{}},
          seeders: [],
        ),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('does not run seeders when connecting fails', () async {
      DatabaseConnectionFactory.debugClear();
      final seeder = _RecordingSeeder();

      await expectLater(
        SeederRunner().setup(database: config(), seeders: [seeder]),
        throwsA(anything),
      );
      expect(seeder.ran, isFalse);
    });

    test('refuses to seed a production database unless forced', () async {
      Env().env['APP_ENV'] = 'production';
      addTearDown(() => Env().env['APP_ENV'] = 'local');
      final seeder = _RecordingSeeder();

      await expectLater(
        SeederRunner().setup(database: config(), seeders: [seeder]),
        throwsA(isA<DatabaseException>()),
      );
      expect(seeder.ran, isFalse);

      await SeederRunner().setup(
        database: config(),
        seeders: [seeder],
        args: ['--force'],
      );
      expect(seeder.ran, isTrue);
    });

    test('closes the connection when a seeder throws', () async {
      await expectLater(
        SeederRunner().setup(database: config(), seeders: [_FailingSeeder()]),
        throwsA(isA<DatabaseException>()),
      );

      expect(connection.closed, isTrue);
    });
  });
}
