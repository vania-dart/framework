import 'dart:async';

import 'package:vania/src/contract/database/_connectors/_database_connection.dart';
import '_database_connection_factory.dart';
import '../_database_utils/_db_config.dart';
import '../monitoring/database_monitor.dart';
import '_database_connection_proxy.dart';

class ConnectionPool {
  final DBConfig config;
  final Future<bool> Function(DatabaseConnection) validator;
  final void Function(Object, StackTrace) onError;
  final List<DatabaseConnection> _availableConnections = [];
  final List<DatabaseConnection> _usedConnections = [];
  final List<Completer<DatabaseConnection>> _waitQueue = [];
  final DatabaseMonitor _monitor = DatabaseMonitor();
  final String _poolId;
  final List<Duration> _queryTimes = [];
  final int _maxQueryTimeHistory = 100;

  int get activeConnections => _usedConnections.length;
  int get totalConnections =>
      _availableConnections.length + _usedConnections.length;
  int get maxSize => config.poolSize;
  int get minSize => 2;

  Future<void> _lock = Future.value();

  ConnectionPool({
    required this.config,
    required this.validator,
    required this.onError,
  }) : _poolId =
            '${config.driver}://${config.host}:${config.port}/${config.database}';

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
          final proxy = DatabaseConnectionProxy(connection, _poolId, _monitor);
          _usedConnections.add(proxy);
          _updateMetrics();
          return proxy;
        } else {
          await connection.close();
        }
      }

      if (_usedConnections.length < maxSize) {
        final connection = DatabaseConnectionFactory.createConnection(config);
        await connection.connect();
        final proxy = DatabaseConnectionProxy(connection, _poolId, _monitor);
        _usedConnections.add(proxy);
        _updateMetrics();
        return proxy;
      } else {
        final completer = Completer<DatabaseConnection>();
        _waitQueue.add(completer);
        return completer.future;
      }
    });
  }

  Future<bool> _validateConnection(DatabaseConnection connection) async {
    return validator(connection);
  }

  Future<void> validateConnections() async {
    await _synchronized(() async {
      final invalidConnections = <DatabaseConnection>[];

      for (final connection in _availableConnections) {
        if (!await _validateConnection(connection)) {
          invalidConnections.add(connection);
        }
      }

      for (final connection in invalidConnections) {
        _availableConnections.remove(connection);
        await connection.close();
      }
    });
  }

  void release(DatabaseConnection connection) {
    _synchronized(() async {
      if (_usedConnections.remove(connection)) {
        if (_waitQueue.isNotEmpty) {
          final completer = _waitQueue.removeAt(0);
          _usedConnections.add(connection);
          completer.complete(connection);
        } else {
          _availableConnections.add(connection);
        }
      }
    });
  }

  Future<void> close() async {
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

  void increaseSize() {
    config.poolSize = config.poolSize + 5;
  }

  void decreaseSize() {
    config.poolSize = (config.poolSize - 5).clamp(minSize, maxSize);
  }

  void recordQueryExecution(String query, Duration duration) {
    _queryTimes.add(duration);
    if (_queryTimes.length > _maxQueryTimeHistory) {
      _queryTimes.removeAt(0);
    }
    _monitor.recordQuery(_poolId, query, duration);
  }

  void _updateMetrics() {
    _monitor.updateConnectionMetrics(
      _poolId,
      ConnectionMetrics(
        activeConnections: activeConnections,
        maxConnections: maxSize,
        usagePercentage: (activeConnections * 100 ~/ maxSize),
      ),
    );
  }
}
