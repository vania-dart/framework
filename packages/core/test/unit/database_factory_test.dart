library;

import 'package:test/test.dart';
import 'package:vania/database.dart';

class _MockConnection implements DatabaseConnection {
  final String label;
  _MockConnection(this.label);
  @override
  Future<void> connect() async {}
  @override
  Future<void> close() async {}
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

void main() {
  setUp(() {
    DatabaseConnectionFactory.debugClear();
  });

  test(
    'two independent driver registrations coexist on the shared factory',
    () {
      DatabaseConnectionFactory.register(
        'driver_a',
        (config) => _MockConnection('a'),
        aliases: const ['a_alias'],
      );
      DatabaseConnectionFactory.register(
        'driver_b',
        (config) => _MockConnection('b'),
        aliases: const ['b_alias'],
      );

      for (final name in const ['driver_a', 'a_alias', 'driver_b', 'b_alias']) {
        expect(
          DatabaseConnectionFactory.isRegistered(name),
          isTrue,
          reason: '$name should resolve on the shared factory',
        );
      }

      final a = DatabaseConnectionFactory.createConnection(
        DBConfig(driver: 'a_alias'),
      );
      final b = DatabaseConnectionFactory.createConnection(
        DBConfig(driver: 'DRIVER_B'),
      );
      expect((a as _MockConnection).label, 'a');
      expect((b as _MockConnection).label, 'b');
    },
  );

  test('unknown driver name throws with a clear message', () {
    expect(
      () => DatabaseConnectionFactory.createConnection(
        DBConfig(driver: 'nonexistent'),
      ),
      throwsA(
        predicate(
          (e) =>
              e.toString().contains('Unsupported driver') ||
              (e as dynamic).message?.contains('Unsupported driver') == true,
          'thrown value carries an "Unsupported driver" message',
        ),
      ),
    );
  });
}
