import 'dart:convert';

import '../contract/database_connection.dart';
import 'package:vania/foundation.dart'
    show DatabaseException, Env, InvalidArgumentException;
import '../connection/connection_manager.dart';
import '../config/db_config.dart';
import 'adapters/mongo_adapter.dart';
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
    final driver = databaseConfig['default'];
    if (driver is! String || driver.isEmpty) {
      throw DatabaseException(
        'A database must be specified: "default" is missing from the '
        'database config.',
      );
    }

    final connections = databaseConfig['connections'];
    if (connections is! Map<String, dynamic> || connections[driver] == null) {
      throw DatabaseException(
        'Database config not valid: no connection named "$driver"',
      );
    }

    try {
      final connectionManager = ConnectionManager();
      connectionManager.defaultConnection = driver;
      _driver = driver;

      await connectionManager.connect(
        _createDBConfig(connections[driver]),
        driver,
      );

      final connection = connectionManager.connection(driver);
      if (connection == null) {
        throw DatabaseException('Failed to open a connection for "$driver"');
      }
      _dbConnection = connection;

      _adapter = _createAdapter(driver);
      await connection.execute(_adapter!.getMigrationsTableSql());
    } on InvalidArgumentException catch (e) {
      throw DatabaseException(e.message);
    }
  }

  @override
  Future<void> truncateMigration() async {
    final connection = _dbConnection;
    final adapter = _adapter;
    if (connection == null || adapter == null) {
      throw DatabaseException(
        'Database connection not established. Call setup() first.',
      );
    }

    final table = adapter.migrationsTable;
    try {
      if (adapter.supports('sqlite') || adapter.supports('sqlite3')) {
        await connection.execute(
          'DELETE FROM ${adapter.escapeIdentifier(table)}',
        );
      } else if (adapter.supports('mongodb') || adapter.supports('mongo')) {
        await connection.execute(
          jsonEncode({'_vania_migration': 'truncateCollection', 'name': table}),
        );
      } else {
        await connection.execute('TRUNCATE ${adapter.escapeIdentifier(table)}');
      }
    } catch (e) {
      throw DatabaseException('Failed to truncate $table table', e);
    }
  }

  @override
  Future<void> closeConnection() async {
    try {
      await _dbConnection?.close();
    } finally {
      _dbConnection = null;
      _driver = null;
      _adapter = null;
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
    final d = driver.toLowerCase();

    if (d == 'mysql') return MySqlAdapter();
    if (d == 'pgsql' || d == 'postgresql' || d == 'postgres') {
      return PostgreSqlAdapter();
    }
    if (d == 'sqlite' || d == 'sqlite3') return SqliteAdapter();
    if (d == 'mongodb' || d == 'mongo') return MongoAdapter();

    return MySqlAdapter();
  }
}
