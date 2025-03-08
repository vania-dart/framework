import '../contract/database/_connectors/_database_connection.dart';
import '../exception/invalid_argument_exception.dart';
import '../logger/logger.dart';
import '_connectors/_database_connection_factory.dart';
import '_connectors/_db_transaction.dart';
import '_database_utils/_db_config.dart';
import '_connectors/_pool_manager.dart';
import '_query_executor.dart';
import '_connectors/_database_connection_proxy.dart';
import 'monitoring/database_monitor.dart';

class ConnectionManager {
  static ConnectionManager? _singleton;
  final Map<String, QueryExecutor> _queryExecutors = {};
  final DatabaseMonitor _monitor = DatabaseMonitor();

  factory ConnectionManager() {
    _singleton ??= ConnectionManager._internal();
    return _singleton!;
  }

  ConnectionManager._internal();

  Map<String, DatabaseConnection> connectionMap = {};
  String? defaultConnection;

  DatabaseConnection? connection([String? connectionName]) =>
      connectionMap[connectionName ?? defaultConnection];

  QueryExecutor getQueryExecutor([String? connectionName]) {
    final conn = connectionName ?? defaultConnection;
    if (conn == null || !connectionMap.containsKey(conn)) {
      throw InvalidArgumentException('Connection not found: $conn');
    }
    return _queryExecutors.putIfAbsent(
      conn,
      () => QueryExecutor(connectionMap[conn]!),
    );
  }

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

      // Wrap the connection with a proxy for monitoring
      final monitoredConnection = DatabaseConnectionProxy(
        connection,
        connectionName,
        _monitor,
      );

      connectionMap[connectionName] = monitoredConnection;

      // Create QueryExecutor for this connection
      _queryExecutors[connectionName] = QueryExecutor(monitoredConnection);
    } on InvalidArgumentException catch (e) {
      Logger.log(e.message, type: Logger.ERROR);
      throw Exception(e.message);
    }
  }

  Future<bool> transaction(
    Future<void> Function() queries, [
    String? connectionName,
  ]) async {
    final transaction = Transaction(connection(connectionName)!);
    try {
      if (await transaction.begin()) {
        await queries();
        if (await transaction.commit()) {
          return true;
        } else {
          await transaction.rollback();
          throw InvalidArgumentException("Transaction commit failed.");
        }
      } else {
        throw InvalidArgumentException("Transaction begin failed.");
      }
    } catch (e) {
      await transaction.rollback();
      throw InvalidArgumentException("Transaction failed: ${e.toString()}");
    }
  }

  // Helper methods for heavy operations
  Future<List<Map<String, dynamic>>> executeHeavyQuery(
    String query,
    Map<String, dynamic> bindings, {
    String? connectionName,
    Duration? timeout,
  }) async {
    return await getQueryExecutor(connectionName).executeHeavySelect(
      query,
      bindings,
      timeout: timeout,
    );
  }

  Future<void> executeBatchOperation(
    List<String> queries,
    List<Map<String, dynamic>> bindingsList, {
    String? connectionName,
    Duration? timeout,
  }) async {
    await getQueryExecutor(connectionName).executeHeavyBatchOperation(
      queries,
      bindingsList,
      timeout: timeout,
    );
  }

  Future<void> importData(
    String table,
    List<Map<String, dynamic>> records, {
    String? connectionName,
    Duration? timeout,
    int batchSize = 1000,
  }) async {
    await getQueryExecutor(connectionName).executeDataImport(
      table,
      records,
      timeout: timeout,
      batchSize: batchSize,
    );
  }


  Stream<DatabaseAlert> get alerts => _monitor.alerts;
  Map<String, PerformanceStats> getPerformanceStats() =>
      _monitor.getPerformanceStats();
}
