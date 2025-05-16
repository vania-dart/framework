import 'dart:async';
import 'dart:io';
import 'package:meta/meta.dart';
import 'package:vania/src/exception/database_exception.dart';
import '../_database_utils/_db_config.dart';
import '_connection_pool.dart';
import 'package:vania/src/contract/database/_connectors/_database_connection.dart';

class PoolManager {
  static final PoolManager _singleton = PoolManager._internal();
  factory PoolManager() => _singleton;
  PoolManager._internal();

  final Map<String, ConnectionPool> _pools = {};
  final Map<String, int> _poolUsage = {};
  final Map<String, DateTime> _lastHealthCheck = {};

  // Pool health check interval
  static const Duration healthCheckInterval = Duration(minutes: 3);

  // Maximum idle time for a connection before it's removed
  static const Duration maxIdleTime = Duration(minutes: 30);

  @visibleForTesting
  ConnectionPool createPool(DBConfig config) {
    final String poolKey = _generatePoolKey(config);
    if (!_pools.containsKey(poolKey)) {
      _pools[poolKey] = ConnectionPool(
        config: config,
        validator: _validateConnection,
        onError: _handlePoolError,
      );
      _startPoolMonitoring(poolKey);
    }
    return _pools[poolKey]!;
  }

  ConnectionPool getPool(DBConfig config) {
    final String poolKey = _generatePoolKey(config);
    return _pools[poolKey] ?? createPool(config);
  }

  Future<void> closeAll() async {
    for (var pool in _pools.values) {
      await pool.close();
    }
    _pools.clear();
    _poolUsage.clear();
    _lastHealthCheck.clear();
  }

  // Validates connection health
  Future<bool> _validateConnection(DatabaseConnection connection) async {
    try {
      await connection.execute('SELECT 1');
      return true;
    } catch (e) {
      throw DatabaseException('Connection validation failed', e);
    }
  }

  // Handles pool errors
  void _handlePoolError(Object error, StackTrace stackTrace) {
    stderr.writeln('Pool error: $error');
    stderr.writeln('Stack trace: $stackTrace');
  }

  // Monitors pool health and usage
  void _startPoolMonitoring(String poolKey) {
    Timer.periodic(healthCheckInterval, (timer) async {
      if (!_pools.containsKey(poolKey)) {
        timer.cancel();
        return;
      }

      final pool = _pools[poolKey]!;
      final usage = _poolUsage[poolKey] ?? 0;
      final lastCheck = _lastHealthCheck[poolKey] ?? DateTime.now();

      // Check pool health
      if (DateTime.now().difference(lastCheck) >= healthCheckInterval) {
        await _performHealthCheck(poolKey, pool);
      }

      // Adjust pool size based on usage patterns
      _adjustPoolSize(pool, usage);

      // Reset usage counter
      _poolUsage[poolKey] = 0;
    });
  }

  Future<void> _performHealthCheck(String poolKey, ConnectionPool pool) async {
    try {
      final activeConnections = pool.activeConnections;
      final totalConnections = pool.totalConnections;

      stderr.writeln('Pool $poolKey stats:');
      stderr.writeln('Active connections: $activeConnections');
      stderr.writeln('Total connections: $totalConnections');

      await pool.validateConnections();

      _lastHealthCheck[poolKey] = DateTime.now();
    } catch (e) {
      throw DatabaseException('Health check failed for pool $poolKey', e);
    }
  }

  void _adjustPoolSize(ConnectionPool pool, int usage) {
    final currentSize = pool.totalConnections;
    final activeConnections = pool.activeConnections;

    // Scale up if high usage or high active connections ratio
    if ((usage > currentSize * 0.8 || activeConnections > currentSize * 0.7) &&
        currentSize < pool.maxSize) {
      pool.increaseSize();
    }

    // Scale down if low usage and low active connections
    if (usage < currentSize * 0.2 &&
        activeConnections < currentSize * 0.3 &&
        currentSize > pool.minSize) {
      pool.decreaseSize();
    }
  }

  String _generatePoolKey(DBConfig config) {
    return '${config.driver}://${config.host}:${config.port}/${config.database}';
  }

  // Track pool usage
  void incrementPoolUsage(String poolKey) {
    _poolUsage[poolKey] = (_poolUsage[poolKey] ?? 0) + 1;
  }
}
