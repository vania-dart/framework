import 'dart:async';

import 'package:vania/src/exception/database_exception.dart';

import '../contract/database/_connectors/_database_connection.dart';
import '../exception/invalid_argument_exception.dart';
import '../logger/logger.dart';
import '_connectors/_database_connection_factory.dart';
import '_connectors/_database_connection_proxy.dart';
import '_database_utils/_db_config.dart';
import 'monitoring/database_monitor.dart';

class ConnectionManager {
  static ConnectionManager? _singleton;
  final DatabaseMonitor _monitor = DatabaseMonitor();

  factory ConnectionManager() {
    _singleton ??= ConnectionManager._internal();
    return _singleton!;
  }

  ConnectionManager._internal();

  Map<String, DatabaseConnection> connectionMap = {};
  String? defaultConnection;

  bool get isConnected => connectionMap.isNotEmpty;

  DatabaseConnection? connection([String? connectionName]) {
    if (connectionName == null || connectionName.isEmpty) {
      connectionName = defaultConnection;
    }
    return connectionMap[connectionName];
  }

  Future<void> connect(DBConfig config, String connectionName) async {
    try {
      final connection = DatabaseConnectionFactory.createConnection(config);
      await connection.connect();

      final monitoredConnection = DatabaseConnectionProxy(
        connection,
        connectionName,
        _monitor,
      );
      connectionMap[connectionName] = monitoredConnection;

      if (!config.pool) {
        await _checkDatabaseHealth(monitoredConnection);
      }
    } on InvalidArgumentException catch (e) {
      Logger.log(e.message, type: Logger.ERROR);
      throw DatabaseException("Failed to connect to the database", e);
    }
  }

  Future<void> _checkDatabaseHealth(DatabaseConnection connection) async {
    Timer.periodic(Duration(minutes: 5), (timer) async {
      try {
        await connection.execute('SELECT 1;');
      } catch (_) {}
    });
  }

  Future<bool> transaction(
    Future<bool> Function() action, [
    String? connectionName,
  ]) async {
    final conn = connectionName ?? defaultConnection;
    if (conn == null) {
      throw DatabaseException("No connection specified for transaction");
    }

    DatabaseConnection? transactionConnection;

    transactionConnection = connection(connectionName);

    if (transactionConnection == null) {
      throw DatabaseException("Connection not found for transaction");
    }

    return await transactionConnection.transaction(action);
  }

  Stream<DatabaseAlert> get alerts => _monitor.alerts;
  Map<String, PerformanceStats> getPerformanceStats() =>
      _monitor.getPerformanceStats();
}
