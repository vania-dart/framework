import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:vania/src/exception/database_exception.dart';
import 'package:vania/src/exception/query_exception.dart';

import '../_database_utils/_db_config.dart';

import '../../contract/database/_connectors/_database_connection.dart';

class PostgresConnector implements DatabaseConnection {
  final DBConfig config;
  late dynamic _connection;

  PostgresConnector(this.config);

  @override
  Future<void> close() async {
    await _connection.close();
  }

  Encoding _getEncoding(String encoding) {
    switch (encoding.toLowerCase()) {
      case 'utf8':
        return Utf8Codec();
      case 'ascii':
        return AsciiCodec();
      case 'latin1':
        return Latin1Codec();
      case 'iso-8859-1':
        return Latin1Codec();
      default:
        return Utf8Codec(allowMalformed: true);
    }
  }

  Future<void> _onOpen(Connection conn, DBConfig configParser) async {
    await conn.execute("SET client_encoding = '${configParser.collation}'");
    if (configParser.schema != null) {
      await conn.execute("SET search_path TO ${configParser.schema}");
    }
    if (configParser.timezone != null) {
      await conn.execute("SET timezone TO '${configParser.timezone}'");
    }
  }

  @override
  Future<void> connect() async {
    final endpoint = Endpoint(
      host: config.host,
      port: config.port,
      database: config.database,
      username: config.username,
      password: config.password,
    );

    final sslMode = config.sslMode ? SslMode.require : SslMode.disable;

    try {
      if (config.pool == true) {
        _connection = Pool.withEndpoints(
          [endpoint],
          settings: PoolSettings(
            timeZone: config.timezone,
            maxConnectionCount: config.poolSize,
            encoding: _getEncoding(config.collation),
            onOpen: (conn) async {
              await _onOpen(conn, config);
            },
            sslMode: sslMode,
          ),
        );
      } else {
        _connection = await Connection.open(endpoint,
            settings: ConnectionSettings(
              timeZone: config.timezone,
              encoding: _getEncoding(config.collation),
              sslMode: sslMode,
              onOpen: (conn) async {
                await _onOpen(conn, config);
              },
            ));
      }
    } catch (e) {
      throw DatabaseException('Database connection failed', e);
    }
  }

  @override
  Future<bool> execute(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final result = await _connection.execute(
        Sql.named(query.replaceAll(':p', '@p')),
        parameters: bindings,
      );
      return result.affectedRows > 0;
    } catch (e) {
      throw QueryException(
        e.toString(),
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> select(String query,
      [Map<String, dynamic> bindings = const {}]) async {
    try {
      final sql = Sql.named(query.replaceAll(':p', '@p'));

      final result = await _connection.execute(
        sql,
        parameters: bindings,
      );
      final rows = result.map((row) => row.toColumnMap()).toList();
      final maps = <Map<String, dynamic>>[];
      if (rows.isNotEmpty) {
        for (final row in rows) {
          final map = <String, dynamic>{};
          for (final col in row.entries) {
            final key = col.key;
            final value =
                col.value is UndecodedBytes ? col.value.asString : col.value;
            map.addAll({key: value});
          }
          maps.add(map);
        }
      }
      return maps;
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
      final result = await _connection.execute(
        Sql.named(query.replaceAll(':p', '@p')),
        parameters: bindings,
      );
      return result.affectedRows;
    } catch (e) {
      throw QueryException(
        e.toString(),
      );
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    return await _connection.runTx<T>((ctx) async {
      final prev = _connection;
      _connection = ctx;
      try {
        return await action();
      } finally {
        _connection = prev;
      }
    });
  }
}
