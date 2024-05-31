import 'package:vania/vania.dart';

class DatabaseClient {
  DatabaseClient._internal();
  static final DatabaseClient _instance = DatabaseClient._internal();
  factory DatabaseClient() => _instance;

  DatabaseDriver? database;

  Future<void> setup() async {
    switch (env('DB_CONNECTION')) {
      case 'mysql':
        database = await MysqlDriver().init();
        database?.connection.reconnectIfMissingConnection();
        break;
      case 'postgressql':
      case 'postgresql':
      case 'pgsql':
        database = await PostgreSQLDriver().init();
        database?.connection.reconnectIfMissingConnection();
        break;
      default:
        break;
    }
  }
}
