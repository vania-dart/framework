import 'dart:io';

import '../../env_handler/env.dart';
import '../../exception/query_exception.dart';
import '../../utils/functions.dart';
import '../_connection_manager.dart';
import '../_database_utils/_db_config.dart';
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
    port: database['port'] ?? '',
    database: database['database'] ?? '',
    username: database['username'] ?? '',
    password: database['password'] ?? '',
    sslMode: database['sslmode'] ?? '',
    collation: database['collation'] ?? '',
    pool: database['pool'] ?? false,
    poolSize: database['poolsize'] ?? 0,
    filePath: database['file_path'] ?? '',
    openInMemorySQLite: database['openInMemorySQLite'] ?? false,
  );

  Future<void> setup({
    required Map<String, dynamic> database,
    required List<Seeder> seeders,
  }) async {
    if (database['default'] == null) {
      stderr.write('❌ Database config not valid');
      exit(1);
    }
    try {
      ConnectionManager().defaultConnection = database['default'];
      Map<String, dynamic> connections = database['connections'];
      await ConnectionManager().connect(
        _config(connections[ConnectionManager().defaultConnection]),
        database['default'],
      );
    } catch (e) {
      stderr.write(e);
      exit(1);
    } finally {
      for (Seeder seeder in seeders) {
        final stopwatch = Stopwatch()..start();
        try {
          await seeder.run();
          stopwatch.stop();
          stderr.writeln(
            ' Seeder ${toSnakeCase(seeder.runtimeType.toString())} executed ....................................\x1B[32m ${stopwatch.elapsedMilliseconds}ms DONE\x1B[0m',
          );
        } on QueryException catch (e) {
          stopwatch.stop();
          stderr.write(e.cause);
          await ConnectionManager().connection(database['default'])!.close();
          exit(1);
        }
      }
      await ConnectionManager().connection(database['default'])!.close();
      stderr.write(
        '\x1B[32m All database seeders executed successfully \x1B[0m',
      );
      exit(0);
    }
  }
}
