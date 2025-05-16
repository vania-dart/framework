import 'package:postgres/postgres.dart';
import 'package:vania/src/exception/database_exception.dart';
import 'package:vania/src/exception/query_exception.dart';

import '../_database_utils/_db_config.dart';

import '../../contract/database/_connectors/_database_connection.dart';

class PostgresConnector implements DatabaseConnection {
  final DBConfig config;
  late Connection _connection;

  PostgresConnector(this.config);

  @override
  Future<void> close() async {
    await _connection.close();
  }

  @override
  Future<void> connect() async {
    try {
      _connection = await Connection.open(
        Endpoint(
          host: config.host,
          database: config.database,
          username: config.username,
          password: config.password,
          port: config.port,
        ),
        settings: ConnectionSettings(
          sslMode: config.sslMode ? SslMode.verifyFull : SslMode.disable,
        ),
      );
    } catch (e) {
      throw DatabaseException('Database connection failed', e);
    }
  }

  @override
  Future<bool> execute(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final result = await _connection.execute(
        Sql.named(query),
        parameters: bindings,
      );
      return result.affectedRows > 0;
    } catch (e) {
      throw QueryException(
        query,
        bindings,
        e,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> select(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final result = await _connection.execute(
        Sql.named(query),
        parameters: bindings,
      );

      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      throw QueryException(
        query,
        bindings,
        e,
      );
    }
  }

  @override
  Future insert(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final result = await _connection.execute(
        Sql.named(query),
        parameters: bindings,
      );
      return result.affectedRows;
    } catch (e) {
      throw QueryException(
        query,
        bindings,
        e,
      );
    }
  }
}
