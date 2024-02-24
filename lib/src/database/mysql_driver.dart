import 'package:eloquent/eloquent.dart';
import 'package:vania/vania.dart';

class MysqlDriver implements DatabaseDriver {
  static final MysqlDriver _singleton = MysqlDriver._internal();
  factory MysqlDriver() => _singleton;
  MysqlDriver._internal();

  Connection? _connection;

  @override
  Connection get connection => _connection!;

  @override
  Future<void> init([DatabaseConfig? config]) async {
    try {
      var manager = Manager();
      manager.addConnection({
        'driver': 'mysql',
        'host': config?.host,
        'port': config?.port,
        'database': config?.database,
        'username': config?.username,
        'password': config?.password,
        'sslmode': config?.sslmode == true ? 'require' : '',
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

  @override
  String get driver => 'Mysql';
}
