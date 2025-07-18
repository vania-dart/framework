import 'package:mysql_dart/mysql_dart.dart';
import 'package:vania/src/exception/database_exception.dart';
import 'package:vania/src/exception/query_exception.dart';
import '../_database_utils/_db_config.dart';
import '../../contract/database/_connectors/_database_connection.dart';

class MySqlConnector implements DatabaseConnection {
  final DBConfig config;
  late dynamic _connection;
  bool _isPool = false;

  MySqlConnector(this.config);

  @override
  Future<void> close() async {
    await _connection.close();
  }

  @override
  Future<void> connect() async {
    try {
      if (config.pool) {
        _isPool = true;
        _connection = MySQLConnectionPool(
          host: config.host,
          port: config.port,
          userName: config.username,
          password: config.password,
          databaseName: config.database,
          collation: config.collation,
          secure: config.sslMode,
          maxConnections: config.poolSize,
        );
      } else {
        _isPool = false;
        _connection = await MySQLConnection.createConnection(
          host: config.host,
          port: config.port,
          userName: config.username,
          password: config.password,
          databaseName: config.database,
          collation: config.collation,
          secure: config.sslMode,
        );
        await _connection.connect();
      }
    } catch (e) {
      throw DatabaseException('Database connection failed', e);
    }
  }

  @override
  Future<bool> execute(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      await _connection.execute(query, bindings);
      return true;
    } catch (e) {
      throw QueryException(
        e.toString(),
      );
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    try {
      if (_isPool) {
        return await (_connection as MySQLConnectionPool)
            .transactional<T>((txConn) async {
          final previous = _connection;
          _connection = txConn;
          _isPool = false;
          try {
            return await action();
          } finally {
            _isPool = true;
            _connection = previous;
          }
        });
      } else {
        return await (_connection as MySQLConnection)
            .transactional<T>((txConn) async {
          final previous = _connection;
          _connection = txConn;
          try {
            return await action();
          } finally {
            _connection = previous;
          }
        });
      }
    } catch (e) {
      throw DatabaseException('Transaction failed', e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> select(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final IResultSet results;

      if (_isPool) {
        results =
            await (_connection as MySQLConnectionPool).execute(query, bindings);
      } else {
        results =
            await (_connection as MySQLConnection).execute(query, bindings);
      }
      if (results.rows.isEmpty) {
        return [];
      }

      return results.rows.map((item) => item.assoc()).toList();
    } catch (e) {
      throw QueryException(
        e.toString(),
      );
    }
  }

  @override
  Future insert(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final IResultSet results;
      if (_isPool) {
        results =
            await (_connection as MySQLConnectionPool).execute(query, bindings);
      } else {
        results =
            await (_connection as MySQLConnection).execute(query, bindings);
      }
      return results.lastInsertID;
    } catch (e) {
      throw QueryException(
        e.toString(),
      );
    }
  }
}
