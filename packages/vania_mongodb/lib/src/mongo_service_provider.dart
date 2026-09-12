import 'package:vania/service_provider.dart';
import 'package:vania/database.dart' show registerOrmValidationRules;
import 'package:vania/foundation.dart' show Config, env;

import 'mongo_config.dart';
import 'mongo_connection.dart';
import 'mongo_db.dart';

class MongoDBServiceProvider extends ServiceProvider {
  const MongoDBServiceProvider();

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

    final defaultConnection = database['default'];
    final connections = database['connections'] as Map<String, dynamic>;
    final config = connections[defaultConnection] as Map<String, dynamic>;
    if ((config['driver'] ?? '').toString().toLowerCase() != 'mongodb') {
      return;
    }

    final connection = MongoConnection(MongoConfig.fromMap(config));
    await connection.connect();
    MongoDB().connection = connection;
  }
}
