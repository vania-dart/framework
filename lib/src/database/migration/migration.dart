import 'dart:io';

import 'package:meta/meta.dart';
import 'package:vania/src/exception/query_exception.dart';
import 'package:vania/src/utils/functions.dart' show toSnakeCase;
import 'builders/schema.dart';
import 'builders/table_definition.dart';
import 'contracts/database_adapter_interface.dart';
import 'migration_connection.dart';

abstract class Migration {
  late final MigrationConnection _connection;
  late final Schema _schemaBuilder;
  late final DatabaseAdapterInterface? _adapter;

  String get migrationName => toSnakeCase(runtimeType.toString());

  Migration() {
    _connection = MigrationConnection();
    _schemaBuilder = Schema();
    _adapter = _connection.adapter;
  }

  @mustBeOverridden
  Future<void> up();

  @mustBeOverridden
  Future<void> down();

  TableDefinition createTable(String tableName, Function(Schema) callback) {
    _schemaBuilder.reset();
    _schemaBuilder.setTableName(tableName);

    Future<void> createFunction() async {
      callback(_schemaBuilder);

      String sql =
          _schemaBuilder.generateCreateTableSql(tableName, ifNotExists: false);

      if (_adapter != null && _adapter.driverName == 'pgsql') {
        final postgresAdapter = _adapter as dynamic;
        if (postgresAdapter.executeStatements != null) {
          await postgresAdapter.executeStatements(sql,
              (String statement) async {
            try {
              await _connection.connection!.execute(statement);
            } on QueryException catch (e) {
              stderr.writeln(
                'Error executing statement: $statement\nError: ${e.cause}',
              );
              exit(0);
            }
          });
          return;
        }
      }

      if (_adapter != null) {
        sql = _adapter.adaptQuery(sql);
      }
      try {
        await _connection.connection!.execute(sql);
      } on QueryException catch (e) {
        stderr.writeln(
          'Error executing statement: $sql\nError: ${e.cause}',
        );
        exit(0);
      }
    }

    return TableDefinition(tableName, createFunction,
        connection: _connection, adapter: _adapter);
  }

  TableDefinition createTableIfNotExists(
      String tableName, Function(Schema) callback) {
    _schemaBuilder.reset();
    _schemaBuilder.setTableName(tableName);

    Future<void> createFunction() async {
      callback(_schemaBuilder);

      String sql =
          _schemaBuilder.generateCreateTableSql(tableName, ifNotExists: true);
      if (_adapter != null && _adapter.driverName == 'pgsql') {
        final postgresAdapter = _adapter as dynamic;
        if (postgresAdapter.executeStatements != null) {
          await postgresAdapter.executeStatements(sql,
              (String statement) async {
            try {
              await _connection.connection!.execute(statement);
            } on QueryException catch (e) {
              stderr.writeln(
                'Error executing statement: $statement\nError: ${e.cause}',
              );
              exit(0);
            }
          });
          return;
        }
      }

      if (_adapter != null) {
        sql = _adapter.adaptQuery(sql);
      }
      try {
        await _connection.connection!.execute(sql);
      } on QueryException catch (e) {
        stderr.writeln(
          'Error executing statement: $sql\nError: ${e.cause}',
        );
        exit(0);
      }
    }

    return TableDefinition(tableName, createFunction,
        connection: _connection, adapter: _adapter);
  }

  Future<void> alterColumn(
    String table,
    Function(Schema) callback, {
    String beforeColumn = '',
    String afterColumn = '',
  }) async {
    _schemaBuilder.reset();
    _schemaBuilder.setTableName(table);

    callback(_schemaBuilder);

    String index = _schemaBuilder.indexes.isNotEmpty
        ? ',ADD ${_schemaBuilder.indexes.join(',')}'
        : '';
    String foreign = _schemaBuilder.foreignKeys.isNotEmpty
        ? ',ADD ${_schemaBuilder.foreignKeys.join(',')}'
        : '';

    String alterQuery = '';
    if (_schemaBuilder.queries.isNotEmpty) {
      alterQuery = 'ADD COLUMN ${_schemaBuilder.queries.first}';
      if (beforeColumn.isNotEmpty) {
        alterQuery = ' $alterQuery BEFORE `$beforeColumn`';
      } else if (afterColumn.isNotEmpty) {
        alterQuery = ' $alterQuery AFTER `$afterColumn`';
      }
    }

    if (_schemaBuilder.queries.isEmpty && index.isNotEmpty) {
      index = index.replaceFirst(',', '');
    }

    if (_schemaBuilder.queries.isEmpty && index.isEmpty) {
      foreign = foreign.replaceFirst(',', '');
    }

    try {
      String query = 'ALTER TABLE `$table` $alterQuery$index$foreign;';
      if (_adapter != null) {
        query = _adapter.adaptQuery(query);
      }

      await _connection.connection!.execute(query);
    } on QueryException catch (e) {
      stderr.writeln(
        '${e.cause}',
      );
      exit(0);
    }
  }

  Future<void> dropTable(String tableName) async {
    String sql =
        _schemaBuilder.generateDropTableSql(tableName, ifExists: false);

    if (_adapter?.driverName == 'mysql') {
      sql =
          'SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;${sql}SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;';
    }

    if (_adapter != null) {
      sql = _adapter.adaptQuery(sql);
    }

    try {
      await _connection.connection!.execute(sql);
    } on QueryException catch (e) {
      stderr.writeln(
        'Error executing statement: $sql\nError: ${e.cause}',
      );
      exit(0);
    }
  }

  Future<void> dropTableIfExists(String tableName) async {
    String sql = _schemaBuilder.generateDropTableSql(tableName, ifExists: true);

    if (_adapter?.driverName == 'mysql') {
      sql =
          'SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;${sql}SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;';
    }

    if (_adapter != null) {
      sql = _adapter.adaptQuery(sql);
    }

    try {
      await _connection.connection!.execute(sql);
    } on QueryException catch (e) {
      stderr.writeln(
        'Error executing statement: $sql\nError: ${e.cause}',
      );
      exit(0);
    }
  }

  Future<void> execute(String sql) async {
    if (_adapter != null) {
      sql = _adapter.adaptQuery(sql);
    }

    try {
      await _connection.connection!.execute(sql);
    } on QueryException catch (e) {
      stderr.writeln(
        'Error executing statement: $sql\nError: ${e.cause}',
      );
      exit(0);
    }
  }
}
