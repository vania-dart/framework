import 'dart:async';

import 'package:vania/src/contract/database/_connectors/_database_connection.dart';
import '_database_connection_factory.dart';
import '../_database_utils/_db_config.dart';

class ConnectionPool {
  final DBConfig config;
  final List<DatabaseConnection> _availableConnections = [];
  final List<DatabaseConnection> _usedConnections = [];
  final List<Completer<DatabaseConnection>> _waitQueue = [];

  Future<void> _lock = Future.value();
  ConnectionPool({required this.config});
  Future<T> _synchronized<T>(Future<T> Function() action) async {
    final previousLock = _lock;
    final completer = Completer<void>();
    _lock = completer.future;
    try {
      await previousLock;
      return await action();
    } finally {
      completer.complete();
    }
  }

  Future<DatabaseConnection> acquire() async {
    return await _synchronized(() async {
      while (_availableConnections.isNotEmpty) {
        final connection = _availableConnections.removeLast();
        if (await _validateConnection(connection)) {
          _usedConnections.add(connection);
          return connection;
        } else {
          await connection.close();
        }
      }
      int poolSize = config.poolSize ?? 0;
      if (_usedConnections.length < poolSize) {
        final connection = DatabaseConnectionFactory.createConnection(config);
        await connection.connect();
        _usedConnections.add(connection);
        return connection;
      } else {
        final completer = Completer<DatabaseConnection>();
        _waitQueue.add(completer);
        return completer.future;
      }
    });
  }

  Future<bool> _validateConnection(DatabaseConnection connection) async {
    try {
      await connection.execute("SELECT 1;");
      return true;
    } catch (e) {
      return false;
    }
  }

  void release(DatabaseConnection connection) {
    if (_usedConnections.remove(connection)) {
      if (_waitQueue.isNotEmpty) {
        final completer = _waitQueue.removeAt(0);
        _usedConnections.add(connection);
        completer.complete(connection);
      } else {
        _availableConnections.add(connection);
      }
    }
  }

  Future<void> closeAll() async {
    await _synchronized(() async {
      for (final connection in [
        ..._availableConnections,
        ..._usedConnections
      ]) {
        await connection.close();
      }
      _availableConnections.clear();
      _usedConnections.clear();
      for (final completer in _waitQueue) {
        if (!completer.isCompleted) {
          completer.completeError("Connection pool is closing.");
        }
      }
      _waitQueue.clear();
    });
  }
}
