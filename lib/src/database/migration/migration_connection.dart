import 'dart:io';

import '../../contract/database/_connectors/_database_connection.dart';
import '../../env_handler/env.dart';
import '../../exception/invalid_argument_exception.dart';
import '../_connection_manager.dart';
import '../_database_utils/_db_config.dart';
import 'adapters/mysql_adapter.dart';
import 'adapters/postgresql_adapter.dart';
import 'adapters/sqlite_adapter.dart';
import 'contracts/database_adapter_interface.dart';
import 'contracts/migration_connection_interface.dart';

class MigrationConnection implements MigrationConnectionInterface {
  static final MigrationConnection _singleton = MigrationConnection._internal();

  DatabaseConnection? _dbConnection;
  String? _driver;
  DatabaseAdapterInterface? _adapter;

  factory MigrationConnection() {
    Env().load();
    return _singleton;
  }

  MigrationConnection._internal();

  @override
  DatabaseConnection? get connection => _dbConnection;

  @override
  String? get driver => _driver;

  DatabaseAdapterInterface? get adapter => _adapter;

  @override
  Future<void> setup(Map<String, dynamic> databaseConfig) async {
    try {
      final connectionManager = ConnectionManager();

      connectionManager.defaultConnection = databaseConfig['default'];

      Map<String, dynamic> connections = databaseConfig['connections'];

      _driver = databaseConfig['default'];
      await connectionManager.connect(
        _createDBConfig(connections[_driver]),
        _driver!,
      );

      _dbConnection = connectionManager.connection(_driver);

      if (_dbConnection == null) {
        stderr.writeln('A database must be specified.');
        exit(1);
      }

      _adapter = _createAdapter(_driver!);

      String migrationSql = _adapter!.getMigrationsTableSql();
      await _dbConnection!.execute(migrationSql);
    } on InvalidArgumentException catch (e) {
      stderr.writeln(e.message);
      exit(1);
    } catch (e) {
      stderr.write(e.toString());
      exit(1);
    }
  }

  @override
  Future<void> truncateMigration() async {
    if (_dbConnection == null) {
      stderr.writeln('Database connection not established');
      exit(1);
    }

    try {
      if (_adapter?.supports('pgsql') == true) {
        await _dbConnection!.execute('TRUNCATE "migrations"');
      } else if (_adapter?.supports('sqlite') == true) {
        await _dbConnection!.execute('DELETE FROM "migrations"');
      } else {
        await _dbConnection!.execute('TRUNCATE `migrations`');
      }
    } catch (e) {
      stderr.writeln('Failed to truncate migrations table: $e');
      exit(1);
    }
  }

  @override
  Future<void> closeConnection() async {
    try {
      await _dbConnection?.close();
      _dbConnection = null;
      _driver = null;
      _adapter = null;
    } catch (e) {
      stderr.writeln('Failed to close connection: $e');
      exit(1);
    }
  }

  DBConfig _createDBConfig(Map<String, dynamic> config) {
    return DBConfig(
      driver: config['driver'] ?? '',
      host: config['host'] ?? '',
      port: config['port'] ?? 0,
      database: config['database'] ?? '',
      username: config['username'] ?? '',
      password: config['password'] ?? '',
      sslMode: config['sslmode'] ?? false,
      collation: config['collation'] ?? '',
      pool: false,
      poolSize: 0,
      filePath: config['file_path'] ?? '',
      openInMemorySQLite: config['openInMemorySQLite'] ?? false,
    );
  }

  DatabaseAdapterInterface _createAdapter(String driver) {
    final normalizedDriver = driver.toLowerCase();

    if (normalizedDriver == 'mysql') {
      return MySqlAdapter();
    } else if (normalizedDriver == 'pgsql' ||
        normalizedDriver == 'postgresql' ||
        normalizedDriver == 'postgres') {
      return PostgreSqlAdapter();
    } else if (normalizedDriver == 'sqlite' || normalizedDriver == 'sqlite3') {
      return SqliteAdapter();
    }

    return MySqlAdapter();
  }
}
