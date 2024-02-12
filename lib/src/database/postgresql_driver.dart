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
  Future<void> init([DatabaseConfig? config]) async {
    try {
      var manager = Manager();
      manager.addConnection({
        'driver': 'pgsql',
        'host': config?.host,
        'port': config?.port,
        'database': config?.database,
        'username': config?.username,
        'password': config?.password,
        'charset': 'utf8',
        'prefix': '',
        'schema': ['public'],
      });
      manager.setAsGlobal();
      _connection = await manager.connection();
    } on InvalidArgumentException catch (e) {
      print(e.cause);
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    await connection.disconnect();
  }
}
