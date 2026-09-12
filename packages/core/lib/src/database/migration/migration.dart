import 'dart:io';

import 'package:meta/meta.dart';
import 'package:vania/foundation.dart'
    show DatabaseException, QueryException, toSnakeCase;
import '../enum/column_index.dart';
import 'blueprint/table_blueprint.dart';
import 'builders/schema.dart';
import 'builders/table_definition.dart';
import 'contracts/database_adapter_interface.dart';
import 'migration_connection.dart';

abstract class Migration {
  late final MigrationConnection _connection;
  late final Schema _schemaBuilder;

  String get migrationName => toSnakeCase(runtimeType.toString());

  Migration() {
    _connection = MigrationConnection();
    _schemaBuilder = Schema();
  }

  /// Resolved on every access rather than cached in the constructor:
  /// migrations are usually instantiated before `MigrationConnection.setup()`
  /// runs, so a value captured at construction time would always be null.
  DatabaseAdapterInterface? get _adapter => _connection.adapter;

  DatabaseAdapterInterface get _requireAdapter {
    final adapter = _adapter;
    if (adapter == null) {
      throw DatabaseException(
        'No migration adapter is available. Call '
        'MigrationConnection().setup(databaseConfig) before running migrations.',
      );
    }
    return adapter;
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
    Future<void> createFunction() async {
      // Reset here rather than at build time: the schema builder is shared
      // across every create()/alterColumn() call on this migration, and the
      // callback only runs when the returned TableDefinition is awaited.
      _schemaBuilder.reset();
      _schemaBuilder.setTableName(tableName);

      callback(_schemaBuilder);

      final statements = _requireAdapter.renderCreateTable(
        _schemaBuilder.toBlueprint(),
        ifNotExists: ifNotExists,
      );
      await _executeStatements(statements);
    }

    return TableDefinition(
      tableName,
      createFunction,
      connection: _connection,
      adapter: _adapter,
    );
  }

  @Deprecated('Use create() with ifNotExists parameter instead')
  TableDefinition createTableIfNotExists(
    String tableName,
    Function(Schema) callback,
  ) {
    return create(tableName, callback, true);
  }

  TableDefinition alterColumn(
    String table,
    Function(Schema) callback, {
    String beforeColumn = '',
    String afterColumn = '',
  }) {
    Future<void> createFunction() async {
      _schemaBuilder.reset();
      _schemaBuilder.setTableName(table);

      callback(_schemaBuilder);

      final statements = _requireAdapter.renderAlterAddColumns(
        table,
        _schemaBuilder.toBlueprint(),
        afterColumn: afterColumn,
        beforeColumn: beforeColumn,
      );
      await _executeStatements(statements);
    }

    return TableDefinition(
      table,
      createFunction,
      connection: _connection,
      adapter: _adapter,
    );
  }

  Future<void> drop(String tableName) async {
    final statements = _requireAdapter.renderDropTable(
      tableName,
      ifExists: true,
    );
    await _executeStatements(statements);
  }

  @Deprecated('Use drop() instead')
  Future<void> dropTableIfExists(String tableName) async {
    await drop(tableName);
  }

  Future<void> dropColumn(String tableName, String columnName) async {
    final statements = _requireAdapter.renderDropColumn(tableName, columnName);
    await _executeStatements(statements);
  }

  Future<void> renameColumn(
    String tableName,
    String oldName,
    String newName,
  ) async {
    final statements = _requireAdapter.renderRenameColumn(
      tableName,
      oldName,
      newName,
    );
    await _executeStatements(statements);
  }

  Future<void> renameTable(String oldName, String newName) async {
    final statements = _requireAdapter.renderRenameTable(oldName, newName);
    await _executeStatements(statements);
  }

  Future<void> addIndex(
    String tableName,
    String indexName,
    List<String> columns, {
    ColumnIndex type = ColumnIndex.indexKey,
  }) async {
    final index = IndexBlueprint(name: indexName, columns: columns, type: type);
    final statements = _requireAdapter.renderAddIndex(tableName, index);
    await _executeStatements(statements);
  }

  Future<void> dropIndex(String tableName, String indexName) async {
    final statements = _requireAdapter.renderDropIndex(tableName, indexName);
    await _executeStatements(statements);
  }

  /// Sends [sql] to the database exactly as written.
  ///
  /// Deliberately not passed through the driver grammar: that rewriter
  /// collapses whitespace, swaps identifier quotes and strips `COMMENT '…'`,
  /// all of which corrupt string literals in statements like `INSERT`. Use
  /// [executeAdapted] to opt into the MySQL-dialect translation.
  Future<void> execute(String sql) async {
    await _executeRaw(sql);
  }

  /// Translates MySQL-dialect DDL into the active driver's dialect before
  /// running it. Only safe for schema statements — the grammar is not
  /// literal-aware.
  Future<void> executeAdapted(String sql) async {
    final adapter = _adapter;
    await _executeRaw(adapter == null ? sql : adapter.adaptQuery(sql));
  }

  Future<void> _executeStatements(List<String> statements) async {
    for (final stmt in statements) {
      await _executeRaw(stmt);
    }
  }

  Future<void> _executeRaw(String sql) async {
    final connection = _connection.connection;
    if (connection == null) {
      throw DatabaseException(
        'Database connection not established. Call '
        'MigrationConnection().setup(databaseConfig) before running migrations.',
      );
    }
    try {
      await connection.execute(sql);
    } on QueryException catch (e) {
      stderr.writeln('Error executing statement: $sql\nError: ${e.cause}');
      rethrow;
    }
  }
}
