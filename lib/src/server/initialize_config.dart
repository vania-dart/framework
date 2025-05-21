import 'package:vania/src/route/route_handler.dart';

import '../database/_database_utils/_db_config.dart';
import '../config/config.dart';
import '../database/_connection_manager.dart';
import '../service/service_provider.dart';
import '../utils/helper.dart';

Future<void> initializeConfig(config) async {
  Config().setApplicationConfig = config;

  if (env('DB_CONNECTION') != null) {
    final Map<String, dynamic> database = config['database'];
    ConnectionManager().defaultConnection = database['default'];
    Map<String, dynamic> connections = database['connections'];
    await ConnectionManager().connect(
      _config(connections[ConnectionManager().defaultConnection]),
      database['default'],
    );
    List<String> additionalConnections =
        database['additional_connections'] ?? <String>[];
    if (additionalConnections.isNotEmpty) {
      for (String connection in additionalConnections) {
        await ConnectionManager().connect(
          _config(connections[connection]),
          connection,
        );
      }
    }
  }

  List<ServiceProvider> providers = config['providers'];
  for (ServiceProvider provider in providers) {
    await provider.register();
    await provider.boot();
  }

  initializeRoutes();
}

DBConfig _config(database) => DBConfig(
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
