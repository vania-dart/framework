import '../contract/database/_connectors/_database_connection.dart';
import '../exception/invalid_argument_exception.dart';
import '../logger/logger.dart';
import '_connectors/_database_connection_factory.dart';
import '_connectors/_db_transaction.dart';
import '_database_utils/_db_config.dart';
import '_connectors/_pool_manager.dart';

class ConnectionManager {
  static ConnectionManager? _singleton;

  factory ConnectionManager() {
    _singleton ??= ConnectionManager._internal();
    return _singleton!;
  }

  ConnectionManager._internal();

  Map<String, DatabaseConnection> connectionMap = {};

  String? defaultConnection;

  DatabaseConnection? connection([String? connectionName]) =>
      connectionMap[connectionName ?? defaultConnection];

  Future<void> connect(DBConfig config, String connectionName) async {
    try {
      DatabaseConnection connection;
      if (config.pool!) {
        final poolManager = PoolManager();
        final pool = poolManager.getPool(config);
        connection = await pool.acquire();
      } else {
        connection = DatabaseConnectionFactory.createConnection(config);
        await connection.connect();
      }
      connectionMap[connectionName] = connection;
    } on InvalidArgumentException catch (e) {
      Logger.log(e.message, type: Logger.ERROR);
      throw Exception(e.message);
    }
  }

  Future<bool> transaction(
    void Function() queries, [
    String? conditionName,
  ]) async {
    final transaction = Transaction(connection(conditionName)!);
    try {
      if (await transaction.begin()) {
        queries();
        if (await transaction.commit()) {
          return true;
        } else {
          await transaction.rollback();
          throw InvalidArgumentException("Transaction commit failed.");
        }
      } else {
        throw InvalidArgumentException("Transaction commit failed.");
      }
    } catch (e) {
      await transaction.rollback();
      throw InvalidArgumentException("Transaction commit failed.");
    }
  }
}
