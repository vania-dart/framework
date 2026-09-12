import 'dart:async';
import 'package:meta/meta.dart';

/// Monitoring surface shared across drivers.
enum AlertType { slowQuery, highConnectionUsage, connectionError, deadlock }

class DatabaseAlert {
  final AlertType type;
  final String message;
  final Map<String, dynamic> details;

  DatabaseAlert({
    required this.type,
    required this.message,
    required this.details,
  });
}

class QueryMetrics {
  final String sql;
  final Duration executionTime;
  final DateTime timestamp;

  QueryMetrics({
    required this.sql,
    required this.executionTime,
    required this.timestamp,
  });
}

class PerformanceStats {
  final Duration averageQueryTime;
  final int totalQueries;
  final int slowQueries;
  final Duration peakExecutionTime;

  PerformanceStats({
    required this.averageQueryTime,
    required this.totalQueries,
    required this.slowQueries,
    required this.peakExecutionTime,
  });
}

class DatabaseMonitor {
  static final DatabaseMonitor _instance = DatabaseMonitor._internal();
  factory DatabaseMonitor() => _instance;
  DatabaseMonitor._internal();

  final Map<String, List<QueryMetrics>> _queryMetrics = {};
  final Map<String, ConnectionMetrics> _connectionMetrics = {};
  final StreamController<DatabaseAlert> _alertController =
      StreamController.broadcast();

  Stream<DatabaseAlert> get alerts => _alertController.stream;

  // Performance thresholds
  static const Duration slowQueryThreshold = Duration(milliseconds: 100);
  static const int highConnectionUsageThreshold = 80;

  void recordQuery(String connectionId, String sql, Duration executionTime) {
    final metrics = QueryMetrics(
      sql: sql,
      executionTime: executionTime,
      timestamp: DateTime.now(),
    );

    _queryMetrics.putIfAbsent(connectionId, () => []).add(metrics);

    if (executionTime > slowQueryThreshold) {
      _alertController.add(
        DatabaseAlert(
          type: AlertType.slowQuery,
          message: 'Slow query detected',
          details: {
            'sql': sql,
            'execution_time': executionTime.inMilliseconds,
            'threshold': slowQueryThreshold.inMilliseconds,
          },
        ),
      );
    }

    if (_queryMetrics[connectionId]!.length > 1000) {
      _queryMetrics[connectionId]!.removeAt(0);
    }
  }

  void updateConnectionMetrics(String connectionId, ConnectionMetrics metrics) {
    _connectionMetrics[connectionId] = metrics;

    if (metrics.usagePercentage > highConnectionUsageThreshold) {
      _alertController.add(
        DatabaseAlert(
          type: AlertType.highConnectionUsage,
          message: 'High connection pool usage detected',
          details: {
            'usage_percentage': metrics.usagePercentage,
            'active_connections': metrics.activeConnections,
            'max_connections': metrics.maxConnections,
          },
        ),
      );
    }
  }

  List<QueryMetrics> getSlowQueries(String connectionId) {
    return _queryMetrics[connectionId]
            ?.where((m) => m.executionTime > slowQueryThreshold)
            .toList() ??
        [];
  }

  Map<String, PerformanceStats> getPerformanceStats() {
    final stats = <String, PerformanceStats>{};

    for (final entry in _queryMetrics.entries) {
      final queries = entry.value;
      if (queries.isEmpty) continue;

      final totalTime = queries.fold<Duration>(
        Duration.zero,
        (sum, metric) => sum + metric.executionTime,
      );

      final peakTime = queries
          .map((m) => m.executionTime)
          .reduce((max, time) => time > max ? time : max);

      final slowCount = queries
          .where((m) => m.executionTime > slowQueryThreshold)
          .length;

      stats[entry.key] = PerformanceStats(
        averageQueryTime: totalTime ~/ queries.length,
        totalQueries: queries.length,
        slowQueries: slowCount,
        peakExecutionTime: peakTime,
      );
    }

    return stats;
  }

  void clearMetrics(String connectionId) {
    _queryMetrics.remove(connectionId);
    _connectionMetrics.remove(connectionId);
  }

  @visibleForTesting
  void reset() {
    _queryMetrics.clear();
    _connectionMetrics.clear();
  }
}

class ConnectionMetrics {
  final int activeConnections;
  final int maxConnections;
  final int usagePercentage;

  ConnectionMetrics({
    required this.activeConnections,
    required this.maxConnections,
    required this.usagePercentage,
  });
}
