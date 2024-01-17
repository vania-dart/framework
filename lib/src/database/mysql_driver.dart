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
  Future<void> init() async {
    DatabaseConfig config = Config().get('database');

    try {
      var manager = Manager();
      manager.addConnection({
        'driver': 'mysql',
        'host': config.host,
        'port': config.port,
        'database': config.database,
        'username': config.username,
        'password': config.password,
        'sslmode': 'require',
      });
      manager.setAsGlobal();

      _connection = await manager.connection();
    } on InvalidArgumentException catch (e) {
      print(e.cause);
    }
  }
}
