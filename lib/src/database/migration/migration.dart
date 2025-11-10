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

  TableDefinition create(
    String tableName,
    Function(Schema) callback, [
    bool ifNotExists = false,
  ]) {
    _schemaBuilder.reset();
    _schemaBuilder.setTableName(tableName);

    Future<void> createFunction() async {
      callback(_schemaBuilder);

      String sql = _schemaBuilder.generateCreateTableSql(
        tableName,
        ifNotExists: ifNotExists,
      );

      if (_adapter != null && _adapter.driverName == 'pgsql') {
        final postgresAdapter = _adapter as dynamic;
        if (postgresAdapter.executeStatements != null) {
          await postgresAdapter.executeStatements(sql, (
            List<String> statements,
          ) async {
            for (String statement in statements) {
              await _connection.connection!.execute(statement);
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
        stderr.writeln('Error executing statement: $sql\nError: ${e.cause}');
        exit(0);
      }
    }

    return TableDefinition(
      tableName,
      createFunction,
      connection: _connection,
      adapter: _adapter,
    );
  }

  @Deprecated('createTableIfNotExists will be deprecated in version 1.1.0')
  TableDefinition createTableIfNotExists(
    String tableName,
    Function(Schema) callback,
  ) {
    _schemaBuilder.reset();
    _schemaBuilder.setTableName(tableName);

    Future<void> createFunction() async {
      callback(_schemaBuilder);

      String sql = _schemaBuilder.generateCreateTableSql(
        tableName,
        ifNotExists: true,
      );
      if (_adapter != null && _adapter.driverName == 'pgsql') {
        final postgresAdapter = _adapter as dynamic;
        if (postgresAdapter.executeStatements != null) {
          await postgresAdapter.executeStatements(sql, (
            String statement,
          ) async {
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
        stderr.writeln('Error executing statement: $sql\nError: ${e.cause}');
        exit(0);
      }
    }

    return TableDefinition(
      tableName,
      createFunction,
      connection: _connection,
      adapter: _adapter,
    );
  }

  TableDefinition alterColumn(
    String table,
    Function(Schema) callback, {
    String beforeColumn = '',
    String afterColumn = '',
  }) {
    _schemaBuilder.reset();
    _schemaBuilder.setTableName(table);
    Future<void> createFunction() async {
      callback(_schemaBuilder);

      try {
        String sql = _schemaBuilder.generateCreateAlterSql(
          table,
          afterColumn: afterColumn,
          beforeColumn: beforeColumn,
        );
        if (_adapter != null) {
          sql = _adapter.adaptQuery(sql);
        }
        await _connection.connection!.execute(sql);
      } on QueryException catch (e) {
        stderr.writeln('${e.cause}');
        exit(0);
      }
    }

    return TableDefinition(
      table,
      createFunction,
      connection: _connection,
      adapter: _adapter,
    );
  }

  Future<void> drop(String tableName) async {
    String sql = _schemaBuilder.generateDropTableSql(tableName, ifExists: true);

    if (_adapter?.driverName == 'mysql') {
      sql =
          'SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;$sql;SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;';
    }

    if (_adapter?.driverName == 'pgsql') {
      sql = '$sql CASCADE';
    }

    if (_adapter != null) {
      sql = _adapter.adaptQuery(sql);
    }

    try {
      await _connection.connection!.execute(sql);
    } on QueryException catch (e) {
      stderr.writeln('Error executing statement: $sql\nError: ${e.cause}');
      exit(0);
    }
  }

  @Deprecated('dropTableIfExists will be deprecated in version 1.1.0')
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
      stderr.writeln('Error executing statement: $sql\nError: ${e.cause}');
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
      stderr.writeln('Error executing statement: $sql\nError: ${e.cause}');
      exit(0);
    }
  }
}
