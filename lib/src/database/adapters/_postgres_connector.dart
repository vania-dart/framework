import 'package:postgres/postgres.dart';

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
    _connection = await Connection.open(
      Endpoint(
        host: config.host,
        database: config.database,
        username: config.username,
        password: config.password,
      ),
      settings: ConnectionSettings(
          sslMode: config.sslMode ? SslMode.require : SslMode.disable),
    );
  }

  @override
  Future execute(String query) async {
    try {
      await _connection.execute(query);
      return true;
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> select(String query) async {
    try {
      return extractColumns(await _connection.execute(query));
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future insert(String query) async {
    if (query.endsWith(';')) {
      query = query.substring(0, query.length - 1);
    }
    try {
      final result =extractColumns(await _connection.execute('$query RETURNING id'));
      return result.last['id'];
    } catch (e) {
      throw Exception(e);
    }
  }

  List<Map<String, dynamic>> extractColumns(Result res) {
    final columns = res.schema.columns;
    return res.map((row) {
      final rowMap = <String, dynamic>{};
      for (int i = 0; i < columns.length; i++) {
        rowMap[columns[i].columnName ?? 'unknow'] = row[i];
      }
      return rowMap;
    }).toList();
  }
}
