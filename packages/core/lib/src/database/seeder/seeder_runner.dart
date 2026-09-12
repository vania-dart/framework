import 'dart:io';

import 'package:vania/foundation.dart'
    show DatabaseException, Env, QueryException, toSnakeCase;
import '../connection/connection_manager.dart';
import '../config/db_config.dart';
import '../environment_guard.dart';
import 'seeder.dart';

class SeederRunner {
  static final SeederRunner _singleton = SeederRunner._internal();

  factory SeederRunner() {
    Env().load();
    return _singleton;
  }

  SeederRunner._internal();

  DBConfig _config(Map<String, dynamic> database) => DBConfig(
    driver: database['driver'] ?? '',
    host: database['host'] ?? '',
    port: database['port'] ?? 0,
    database: database['database'] ?? '',
    username: database['username'] ?? '',
    password: database['password'] ?? '',
    sslMode: database['sslmode'] ?? false,
    collation: database['collation'] ?? '',
    pool: database['pool'] ?? false,
    poolSize: database['poolsize'] ?? 0,
    filePath: database['file_path'] ?? '',
    openInMemorySQLite: database['openInMemorySQLite'] ?? false,
  );

  Future<void> setup({
    required Map<String, dynamic> database,
    required List<Seeder> seeders,
    List<String> args = const [],
  }) async {
    guardEnvironment('migrate:seed', force: hasForceFlag(args));

    final defaultConnection = database['default'];
    if (defaultConnection == null) {
      throw DatabaseException(
        'Database config not valid: "default" is missing',
      );
    }

    final connections = database['connections'];
    if (connections is! Map<String, dynamic> ||
        connections[defaultConnection] == null) {
      throw DatabaseException(
        'Database config not valid: no connection named "$defaultConnection"',
      );
    }

    ConnectionManager().defaultConnection = defaultConnection;
    await ConnectionManager().connect(
      _config(connections[defaultConnection]),
      defaultConnection,
    );

    try {
      for (final seeder in seeders) {
        final stopwatch = Stopwatch()..start();
        final name = toSnakeCase(seeder.runtimeType.toString());
        try {
          await seeder.run();
          stopwatch.stop();
          stderr.writeln(
            ' Seeder $name executed ....................................\x1B[32m ${stopwatch.elapsedMilliseconds}ms DONE\x1B[0m',
          );
        } on QueryException catch (e) {
          stopwatch.stop();
          throw DatabaseException('Seeder $name failed', e.cause);
        }
      }
      stderr.writeln(
        '\x1B[32m All database seeders executed successfully \x1B[0m',
      );
    } finally {
      await ConnectionManager().connection(defaultConnection)?.close();
    }
  }
}
