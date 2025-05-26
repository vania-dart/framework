import 'dart:isolate';

import '_connection_manager.dart';
import '_database_utils/_db_config.dart';

class IsolateDB {
  static Future<T> run<T>(
    Future<T> Function() callback,
    Map<String, dynamic> dbConfig,
  ) async {
    return await Isolate.run(() async {
      ConnectionManager().defaultConnection = dbConfig['driver'];
      final config = DBConfig(
        driver: dbConfig['driver'] ?? '',
        host: dbConfig['host'] ?? '',
        port: dbConfig['port'] ?? 3306,
        database: dbConfig['database'] ?? '',
        username: dbConfig['username'] ?? '',
        password: dbConfig['password'] ?? '',
        sslMode: dbConfig['sslmode'] ?? false,
        collation: dbConfig['collation'] ?? 'utf8mb4_general_ci',
        pool: false,
        poolSize: 0,
        filePath: dbConfig['file_path'],
        openInMemorySQLite: dbConfig['openInMemorySQLite'] ?? false,
      );
      try {
        await ConnectionManager().connect(
          config,
          dbConfig['driver'],
        );
        return await callback();
      } finally {
        await ConnectionManager().connection(dbConfig['driver'])?.close();
      }
    });
  }
}
