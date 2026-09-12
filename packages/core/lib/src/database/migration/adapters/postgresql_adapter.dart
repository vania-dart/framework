import '../../enum/column_index.dart';
import '../blueprint/column_blueprint.dart';
import '../blueprint/table_blueprint.dart';
import '../contracts/database_adapter_interface.dart';
import 'grammar/postgresql_grammar.dart';

class PostgreSqlAdapter implements DatabaseAdapterInterface {
  late final PostgreSqlGrammar _grammar;

  PostgreSqlAdapter() {
    _grammar = PostgreSqlGrammar();
  }

  @override
  String get driverName => 'pgsql';

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
	"id" SERIAL NOT NULL PRIMARY KEY,
	"migration" VARCHAR(255) NOT NULL,
	"batch" INTEGER NOT NULL DEFAULT 1
);
''';
  }

  @override
  bool supports(String driver) {
    final d = driver.toLowerCase();
    return d == 'pgsql' || d == 'postgresql' || d == 'postgres';
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
    if (value is bool) return value ? 'TRUE' : 'FALSE';
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
    bool hasSerial = false;

    for (final col in blueprint.columns) {
      final isAutoIncrPrimary =
          col.autoIncrement && col.name == blueprint.primaryKey;
      if (isAutoIncrPrimary) hasSerial = true;
      parts.add('  ${_renderColumn(col, isAutoIncrPrimary)}');
    }

    if (blueprint.primaryKey != null && !hasSerial) {
      parts.add('  PRIMARY KEY ("${blueprint.primaryKey}")');
    }

    for (final uc in blueprint.uniqueConstraints) {
      final cols = uc.columns.map((c) => '"$c"').join(', ');
      parts.add('  CONSTRAINT "${uc.name}" UNIQUE ($cols)');
    }

    for (final fk in blueprint.foreignKeys) {
      final constraint = fk.constrained
          ? 'CONSTRAINT "FK_${blueprint.tableName}_${fk.referencesTable}" '
          : '';
      parts.add(
        '  ${constraint}FOREIGN KEY ("${fk.columnName}") '
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

    statements.addAll(_columnComments(blueprint.tableName, blueprint.columns));

    return statements;
  }

  /// PostgreSQL keeps column comments out of the column definition, so they
  /// need their own statements rather than being dropped on the floor.
  List<String> _columnComments(
    String tableName,
    List<ColumnBlueprint> columns,
  ) {
    return [
      for (final col in columns)
        if (col.comment != null)
          'COMMENT ON COLUMN ${escapeIdentifier(tableName)}.'
              '${escapeIdentifier(col.name)} IS ${formatValue(col.comment)}',
    ];
  }

  String _renderColumn(ColumnBlueprint col, bool isAutoIncrPrimary) {
    final buf = StringBuffer('"${col.name}" ');

    if (isAutoIncrPrimary) {
      buf.write('SERIAL NOT NULL PRIMARY KEY');
      return buf.toString();
    }

    buf.write(_pgType(col));

    // `collation` is intentionally not emitted: the values migrations carry
    // are MySQL collation names (`utf8mb4_unicode_ci`) which PostgreSQL does
    // not recognise. Comments are emitted separately by _columnComments.

    buf.write(col.nullable ? ' NULL' : ' NOT NULL');

    if (col.unique) buf.write(' UNIQUE');

    if (col.defaultValue != null) {
      buf.write(' DEFAULT ${_renderDefault(col.defaultValue)}');
    }

    if (col.expression != null) {
      buf.write(' GENERATED ALWAYS AS (${col.expression}) STORED');
    }

    return buf.toString();
  }

  String _pgType(ColumnBlueprint col) {
    switch (col.type) {
      case ColumnType.bigInt:
        return 'BIGINT';
      case ColumnType.integer:
        return 'INTEGER';
      case ColumnType.tinyInt:
      case ColumnType.smallInt:
        return 'SMALLINT';
      case ColumnType.mediumInt:
        return 'INTEGER';
      case ColumnType.float:
        return 'REAL';
      case ColumnType.double:
        return 'DOUBLE PRECISION';
      case ColumnType.decimal:
        if (col.precision != null && col.scale != null) {
          return 'DECIMAL(${col.precision},${col.scale})';
        }
        return 'DECIMAL';
      case ColumnType.varchar:
        return 'VARCHAR(${col.length ?? 255})';
      case ColumnType.char:
        return 'CHAR(${col.length ?? 50})';
      case ColumnType.text:
      case ColumnType.tinyText:
      case ColumnType.mediumText:
      case ColumnType.longText:
        return 'TEXT';
      case ColumnType.json:
        return 'JSONB';
      case ColumnType.uuid:
        return 'UUID';
      case ColumnType.binary:
      case ColumnType.varBinary:
      case ColumnType.blob:
      case ColumnType.tinyBlob:
      case ColumnType.mediumBlob:
      case ColumnType.longBlob:
        return 'BYTEA';
      case ColumnType.date:
        return 'DATE';
      case ColumnType.time:
        return 'TIME';
      case ColumnType.year:
        return 'INTEGER';
      case ColumnType.dateTime:
      case ColumnType.timestamp:
        return 'TIMESTAMP';
      case ColumnType.point:
        return 'POINT';
      case ColumnType.lineString:
        return 'LINE';
      case ColumnType.polygon:
        return 'POLYGON';
      case ColumnType.geometry:
        return 'POINT';
      case ColumnType.multiPoint:
      case ColumnType.multiLineString:
      case ColumnType.multiPolygon:
      case ColumnType.geometryCollection:
        return 'JSONB';
      case ColumnType.enumType:
        return 'VARCHAR(255)';
      case ColumnType.setType:
        return 'VARCHAR(255)';
      case ColumnType.boolean:
        return 'BOOLEAN';
      case ColumnType.bit:
        return 'BOOLEAN';
    }
  }

  String _renderDefault(dynamic value) {
    final funcRegex = RegExp(
      r'^(CURRENT_TIMESTAMP|NOW\(\)|UUID\(\)|RAND\(\))$',
      caseSensitive: false,
    );
    final str = value.toString();
    if (funcRegex.hasMatch(str)) {
      if (str.toUpperCase() == 'RAND()') return 'RANDOM()';
      if (str.toUpperCase() == 'UUID()') return 'gen_random_uuid()';
      return str;
    }
    if (value is int) return '$value';
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    return "'$value'";
  }

  @override
  List<String> renderAlterAddColumns(
    String table,
    TableBlueprint changes, {
    String afterColumn = '',
    String beforeColumn = '',
  }) {
    final statements = <String>[];

    for (final col in changes.columns) {
      statements.add(
        'ALTER TABLE "$table" ADD COLUMN ${_renderColumn(col, false)}',
      );
    }

    statements.addAll(_columnComments(table, changes.columns));

    if (changes.primaryKey != null) {
      statements.add(
        'ALTER TABLE "$table" ADD PRIMARY KEY ("${changes.primaryKey}")',
      );
    }

    for (final uc in changes.uniqueConstraints) {
      final cols = uc.columns.map((c) => '"$c"').join(', ');
      statements.add(
        'ALTER TABLE "$table" ADD CONSTRAINT "${uc.name}" UNIQUE ($cols)',
      );
    }

    for (final idx in changes.indexes) {
      statements.addAll(renderAddIndex(table, idx));
    }

    for (final fk in changes.foreignKeys) {
      final constraint = fk.constrained
          ? 'CONSTRAINT "FK_${table}_${fk.referencesTable}" '
          : '';
      statements.add(
        'ALTER TABLE "$table" ADD ${constraint}FOREIGN KEY ("${fk.columnName}") '
        'REFERENCES "${fk.referencesTable}" ("${fk.referencesColumn}") '
        'ON UPDATE ${fk.onUpdate} ON DELETE ${fk.onDelete}',
      );
    }

    return statements;
  }

  @override
  List<String> renderTableOptions(
    String tableName, {
    String? engine,
    String? charset,
    String? collation,
    String? comment,
    int? autoIncrement,
  }) {
    // ENGINE / CHARSET / COLLATE / AUTO_INCREMENT have no PostgreSQL
    // equivalent; only the comment survives.
    if (comment == null) return const [];
    return [
      'COMMENT ON TABLE ${escapeIdentifier(tableName)} IS '
          '${formatValue(comment)}',
    ];
  }

  @override
  List<String> renderDropTable(String tableName, {bool ifExists = false}) {
    final drop = ifExists ? 'DROP TABLE IF EXISTS' : 'DROP TABLE';
    return ['$drop "$tableName" CASCADE'];
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
