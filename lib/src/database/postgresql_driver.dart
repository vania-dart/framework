import 'package:eloquent/eloquent.dart';
import 'package:vania/vania.dart';

class PostgreSQLDriver implements DatabaseDriver {
  static final PostgreSQLDriver _singleton = PostgreSQLDriver._internal();
  factory PostgreSQLDriver() => _singleton;
  PostgreSQLDriver._internal();

  Connection? _connection;

  @override
  Connection get connection => _connection!;

  @override
  Future<DatabaseDriver?> init() async {
    try {
      var manager = Manager();
      manager.addConnection({
        'driver': 'pgsql',
        'host': env<String>('DB_HOST', '127.0.0.1'),
        'port': env<int>('DB_PORT', 5432),
        'database': env<String>('DB_DATABASE', 'vania'),
        'username': env<String>('DB_USERNAME', 'root'),
        'password': env<String>('DB_PASSWORD', ''),
        //'sslmode': env<bool>('DB_SSL_MODE',true) == true  ? 'require' : '',
        'pool': env<bool>('DB_POOL', false),
        'poolsize': env<int>('DB_POOL_SIZE', 0),
        'charset': env<String>('DB_CHARSET', 'utf8'),
        'prefix': env<String>('DB_PREFIX', ''),
        'schema': env<String>('DB_SCHEMA', 'public'),
      });
      manager.setAsGlobal();
      _connection = await manager.connection();
      return this;
    } on InvalidArgumentException catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    await connection.disconnect();
  }

  @override
  String get driver => 'Postgresql';
}
