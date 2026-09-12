import 'package:vania/service_provider.dart';
import 'package:vania/foundation.dart' show Config, env;

import 'config/db_config.dart';
import 'connection/connection_manager.dart';
import 'validation/unique_validation.dart';

class DatabaseServiceProvider extends ServiceProvider {
  const DatabaseServiceProvider();

  @override
  Future<void> register() async {
    registerOrmValidationRules();
  }

  @override
  Future<void> boot() async {
    final database = Config().get('database');
    if (env('DB_CONNECTION') == null || database == null) {
      return;
    }

    ConnectionManager().defaultConnection = database['default'];
    final Map<String, dynamic> connections = database['connections'];
    await ConnectionManager().connect(
      _config(connections[ConnectionManager().defaultConnection]),
      database['default'],
    );

    final List<String> additionalConnections =
        database['additional_connections'] ?? <String>[];
    for (final connection in additionalConnections) {
      await ConnectionManager().connect(
        _config(connections[connection]),
        connection,
      );
    }
  }

  DBConfig _config(Map<String, dynamic> database) => DBConfig(
    driver: database['driver'] ?? '',
    host: database['host'] ?? '',
    port: database['port'] ?? 0,
    database: database['database'] ?? '',
    username: database['username'] ?? '',
    password: database['password'] ?? '',
    sslMode: database['sslmode'] ?? false,
    collation: database['collation'] ?? 'utf8',
    timezone: database['timezone'] ?? 'UTC',
    pool: database['pool'] ?? false,
    poolSize: database['poolsize'] ?? 2,
    filePath: database['file_path'] ?? '',
    schema: database['schema'] ?? 'public',
    openInMemorySQLite: database['openInMemorySQLite'] ?? false,
  );
}
