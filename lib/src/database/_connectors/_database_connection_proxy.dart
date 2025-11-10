import 'package:vania/src/contract/database/_connectors/_database_connection.dart';
import 'package:vania/src/exception/database_exception.dart'
    show DatabaseException;

import '../../logger/logger.dart';
import '../monitoring/database_monitor.dart';

class DatabaseConnectionProxy implements DatabaseConnection {
  final DatabaseConnection _connection;
  final DatabaseMonitor _monitor;
  final String _connectionId;

  DatabaseConnectionProxy(this._connection, this._connectionId, this._monitor);

  // Expose the underlying connection for pool management
  DatabaseConnection get underlyingConnection => _connection;

  @override
  Future<void> connect() => _connection.connect();

  @override
  Future<void> close() => _connection.close();

  String _formatQuery(String? query, Map<String, dynamic> bindings) {
    if (query == null) {
      Logger.log(
        'Warning: Null query received in _formatQuery',
        type: Logger.WARNING,
      );
      return 'INVALID QUERY: NULL';
    }

    try {
      var formattedQuery = query;

      if (bindings.isEmpty) {
        return formattedQuery;
      }

      final sortedBindings = bindings.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

      for (var entry in sortedBindings) {
        final placeholder = ':${entry.key}';
        final value = entry.value;
        final formattedValue = _formatValue(value);
        formattedQuery = formattedQuery.replaceAll(placeholder, formattedValue);
      }

      return formattedQuery;
    } catch (e) {
      Logger.log('Error formatting query: $e', type: Logger.ERROR);
      throw DatabaseException('Error formatting query: $query', e);
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is DateTime) return "'${value.toIso8601String()}'";
    if (value is bool) return value ? '1' : '0';
    if (value is List) return value.map(_formatValue).join(', ');
    return value.toString();
  }

  @override
  Future<bool> execute(
    String query, [
    Map<String, dynamic> bindings = const {},
  ]) async {
    final startTime = DateTime.now();
    try {
      final formattedQuery = _formatQuery(query, bindings);
      final result = await _connection.execute(query, bindings);
      final duration = DateTime.now().difference(startTime);
      _monitor.recordQuery(_connectionId, formattedQuery, duration);
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _monitor.recordQuery(
        _connectionId,
        'Failed: ${_formatQuery(query, bindings)} - Error: $e',
        duration,
      );
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> select(
    String query, [
    Map<String, dynamic> bindings = const {},
  ]) async {
    final startTime = DateTime.now();
    try {
      final formattedQuery = _formatQuery(query, bindings);
      final result = await _connection.select(query, bindings);
      final duration = DateTime.now().difference(startTime);
      _monitor.recordQuery(_connectionId, formattedQuery, duration);
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _monitor.recordQuery(
        _connectionId,
        'Failed: ${_formatQuery(query, bindings)} - Error: $e',
        duration,
      );
      rethrow;
    }
  }

  @override
  Future<dynamic> insert(
    String query, [
    Map<String, dynamic> bindings = const {},
  ]) async {
    final startTime = DateTime.now();
    try {
      final formattedQuery = _formatQuery(query, bindings);
      final result = await _connection.insert(query, bindings);
      final duration = DateTime.now().difference(startTime);
      _monitor.recordQuery(_connectionId, formattedQuery, duration);
      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _monitor.recordQuery(
        _connectionId,
        'Failed: ${_formatQuery(query, bindings)} - Error: $e',
        duration,
      );
      rethrow;
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async =>
      _connection.transaction(action);
}
