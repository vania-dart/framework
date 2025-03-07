import 'package:mysql_client/mysql_client.dart';
import '../_database_utils/_db_config.dart';
import '../../contract/database/_connectors/_database_connection.dart';

class MySqlConnector implements DatabaseConnection {
  final DBConfig config;
  late MySQLConnection _connection;

  MySqlConnector(this.config);

  @override
  Future<void> close() async {
    await _connection.close();
  }

  @override
  Future<void> connect() async {
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

  @override
  Future<bool> execute(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      await _connection.execute(query, bindings);
      return true;
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> select(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final results = await _connection.execute(query, bindings);
      if (results.rows.isEmpty) {
        return [];
      }
      return results.rows.map((item) => item.assoc()).toList();
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Future<BigInt> insert(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final results = await _connection.execute(query, bindings);
      return results.lastInsertID;
    } catch (e) {
      throw Exception(e);
    }
  }
}
