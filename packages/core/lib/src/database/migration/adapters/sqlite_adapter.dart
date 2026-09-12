import '../../enum/column_index.dart';
import '../blueprint/column_blueprint.dart';
import '../blueprint/table_blueprint.dart';
import '../contracts/database_adapter_interface.dart';
import 'grammar/sqlite_grammar.dart';

class SqliteAdapter implements DatabaseAdapterInterface {
  late final SqliteGrammar _grammar;

  SqliteAdapter() {
    _grammar = SqliteGrammar();
  }

  @override
  String get driverName => 'sqlite';

  @override
  String get migrationsTable => 'migrations';

  @override
  String adaptQuery(String query) {
    return _grammar.convertQuery(query);
  }

  @override
  String getMigrationsTableSql() {
    return '''
CREATE TABLE IF NOT EXISTS "migrations" (
	"id" INTEGER PRIMARY KEY AUTOINCREMENT,
	"migration" TEXT NOT NULL,
	"batch" INTEGER NOT NULL DEFAULT 1
);
''';
  }

  @override
  bool supports(String driver) {
    final d = driver.toLowerCase();
    return d == 'sqlite' || d == 'sqlite3';
  }

  @override
  String escapeIdentifier(String identifier) {
    return '"$identifier"';
  }

  @override
  String formatValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is String) return "'${value.replaceAll("'", "''")}'";
    if (value is num) return value.toString();
    if (value is bool) return value ? '1' : '0';
    return "'$value'";
  }

  @override
  List<String> renderCreateTable(
    TableBlueprint blueprint, {
    bool ifNotExists = false,
  }) {
    final statements = <String>[];
    final buf = StringBuffer();
    final createClause = ifNotExists
        ? 'CREATE TABLE IF NOT EXISTS'
        : 'CREATE TABLE';

    buf.writeln('$createClause "${blueprint.tableName}" (');

    final parts = <String>[];
    bool hasAutoIncr = false;

    for (final col in blueprint.columns) {
      final isAutoIncrPrimary =
          col.autoIncrement && col.name == blueprint.primaryKey;
      if (isAutoIncrPrimary) hasAutoIncr = true;
      parts.add('  ${_renderColumn(col, isAutoIncrPrimary)}');
    }

    if (blueprint.primaryKey != null && !hasAutoIncr) {
      parts.add('  PRIMARY KEY ("${blueprint.primaryKey}")');
    }

    for (final uc in blueprint.uniqueConstraints) {
      final cols = uc.columns.map((c) => '"$c"').join(', ');
      parts.add('  CONSTRAINT "${uc.name}" UNIQUE ($cols)');
    }

    for (final fk in blueprint.foreignKeys) {
      parts.add(
        '  FOREIGN KEY ("${fk.columnName}") '
        'REFERENCES "${fk.referencesTable}" ("${fk.referencesColumn}") '
        'ON UPDATE ${fk.onUpdate} ON DELETE ${fk.onDelete}',
      );
    }

    buf.write(parts.join(',\n'));
    buf.write('\n)');

    statements.add(buf.toString());

    for (final idx in blueprint.indexes) {
      statements.addAll(renderAddIndex(blueprint.tableName, idx));
    }

    return statements;
  }

  String _renderColumn(ColumnBlueprint col, bool isAutoIncrPrimary) {
    final buf = StringBuffer('"${col.name}" ');

    if (isAutoIncrPrimary) {
      buf.write('INTEGER PRIMARY KEY AUTOINCREMENT');
      return buf.toString();
    }

    buf.write(_sqliteType(col));

    buf.write(col.nullable ? ' NULL' : ' NOT NULL');

    if (col.unique) buf.write(' UNIQUE');

    if (col.defaultValue != null) {
      buf.write(' DEFAULT ${_renderDefault(col.defaultValue)}');
    }

    return buf.toString();
  }

  String _sqliteType(ColumnBlueprint col) {
    switch (col.type) {
      case ColumnType.bigInt:
      case ColumnType.integer:
      case ColumnType.tinyInt:
      case ColumnType.smallInt:
      case ColumnType.mediumInt:
      case ColumnType.year:
      case ColumnType.bit:
      case ColumnType.boolean:
        return 'INTEGER';
      case ColumnType.float:
      case ColumnType.double:
      case ColumnType.decimal:
        return 'REAL';
      case ColumnType.varchar:
      case ColumnType.char:
      case ColumnType.text:
      case ColumnType.tinyText:
      case ColumnType.mediumText:
      case ColumnType.longText:
      case ColumnType.json:
      case ColumnType.uuid:
      case ColumnType.date:
      case ColumnType.time:
      case ColumnType.dateTime:
      case ColumnType.timestamp:
        return 'TEXT';
      case ColumnType.binary:
      case ColumnType.varBinary:
      case ColumnType.blob:
      case ColumnType.tinyBlob:
      case ColumnType.mediumBlob:
      case ColumnType.longBlob:
        return 'BLOB';
      case ColumnType.point:
      case ColumnType.lineString:
      case ColumnType.polygon:
      case ColumnType.geometry:
      case ColumnType.multiPoint:
      case ColumnType.multiLineString:
      case ColumnType.multiPolygon:
      case ColumnType.geometryCollection:
        return 'TEXT';
      case ColumnType.enumType:
        if (col.enumValues != null && col.enumValues!.isNotEmpty) {
          final vals = col.enumValues!.map(formatValue).join(', ');
          return 'TEXT CHECK (${escapeIdentifier(col.name)} IN ($vals))';
        }
        return 'TEXT';
      case ColumnType.setType:
        return 'TEXT';
    }
  }

  String _renderDefault(dynamic value) {
    final funcRegex = RegExp(
      r'^(CURRENT_TIMESTAMP|NOW\(\)|UUID\(\)|RAND\(\))$',
      caseSensitive: false,
    );
    final str = value.toString();
    if (funcRegex.hasMatch(str)) return str;
    if (value is int) return '$value';
    if (value is bool) return value ? '1' : '0';
    return "'$value'";
  }

  @override
  List<String> renderAlterAddColumns(
    String table,
    TableBlueprint changes, {
    String afterColumn = '',
    String beforeColumn = '',
  }) {
    // SQLite's ALTER TABLE cannot add these after the fact, and quietly
    // dropping them would leave the schema silently missing a constraint.
    final unsupported = <String>[
      if (changes.primaryKey != null) 'a primary key',
      if (changes.uniqueConstraints.isNotEmpty) 'unique constraints',
      if (changes.foreignKeys.isNotEmpty) 'foreign keys',
    ];
    if (unsupported.isNotEmpty) {
      throw UnsupportedError(
        'SQLite cannot add ${unsupported.join(', ')} to the existing table '
        '"$table". Recreate the table with the constraint instead.',
      );
    }

    final statements = <String>[];

    for (final col in changes.columns) {
      statements.add(
        'ALTER TABLE "$table" ADD COLUMN ${_renderColumn(col, false)}',
      );
    }

    for (final idx in changes.indexes) {
      statements.addAll(renderAddIndex(table, idx));
    }

    return statements;
  }

  /// SQLite has no table-level options, so every one of these is dropped.
  @override
  List<String> renderTableOptions(
    String tableName, {
    String? engine,
    String? charset,
    String? collation,
    String? comment,
    int? autoIncrement,
  }) => const [];

  @override
  List<String> renderDropTable(String tableName, {bool ifExists = false}) {
    final drop = ifExists ? 'DROP TABLE IF EXISTS' : 'DROP TABLE';
    return ['$drop "$tableName"'];
  }

  @override
  List<String> renderDropColumn(String tableName, String columnName) {
    return ['ALTER TABLE "$tableName" DROP COLUMN "$columnName"'];
  }

  @override
  List<String> renderRenameColumn(
    String tableName,
    String oldName,
    String newName,
  ) {
    return ['ALTER TABLE "$tableName" RENAME COLUMN "$oldName" TO "$newName"'];
  }

  @override
  List<String> renderRenameTable(String oldName, String newName) {
    return ['ALTER TABLE "$oldName" RENAME TO "$newName"'];
  }

  @override
  List<String> renderAddIndex(String tableName, IndexBlueprint index) {
    final cols = index.columns.map((c) => '"$c"').join(', ');
    String prefix = '';
    if (index.type == ColumnIndex.unique) prefix = 'UNIQUE ';
    return [
      'CREATE ${prefix}INDEX IF NOT EXISTS "${index.name}" ON "$tableName" ($cols)',
    ];
  }

  @override
  List<String> renderDropIndex(String tableName, String indexName) {
    return ['DROP INDEX IF EXISTS "$indexName"'];
  }
}
