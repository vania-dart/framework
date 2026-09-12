import '../../enum/column_index.dart';
import '../blueprint/column_blueprint.dart';
import '../blueprint/table_blueprint.dart';
import '../contracts/database_adapter_interface.dart';
import 'grammar/mysql_grammar.dart';

class MySqlAdapter implements DatabaseAdapterInterface {
  late final MySqlGrammar _grammar;

  MySqlAdapter() {
    _grammar = MySqlGrammar();
  }

  @override
  String get driverName => 'mysql';

  @override
  String get migrationsTable => 'migrations';

  @override
  String adaptQuery(String query) {
    return _grammar.convertQuery(query);
  }

  @override
  String getMigrationsTableSql() {
    return '''
CREATE TABLE IF NOT EXISTS `migrations` (
	`id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
	`migration` VARCHAR(255) NOT NULL COLLATE 'utf8mb4_unicode_ci',
	`batch` INT(10) UNSIGNED NOT NULL DEFAULT 1,
	PRIMARY KEY (`id`) USING BTREE
)
COLLATE='utf8mb4_unicode_ci'
ENGINE=InnoDB
;
''';
  }

  @override
  bool supports(String driver) {
    return driver.toLowerCase() == 'mysql';
  }

  @override
  String escapeIdentifier(String identifier) {
    return '`$identifier`';
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
    final buf = StringBuffer();
    final createClause = ifNotExists
        ? 'CREATE TABLE IF NOT EXISTS'
        : 'CREATE TABLE';

    buf.writeln('$createClause `${blueprint.tableName}` (');

    final parts = <String>[];

    for (final col in blueprint.columns) {
      parts.add('  ${_renderColumn(col)}');
    }

    if (blueprint.primaryKey != null) {
      final algo = blueprint.primaryAlgorithm.isNotEmpty
          ? ' USING ${blueprint.primaryAlgorithm}'
          : '';
      parts.add('  PRIMARY KEY (`${blueprint.primaryKey}`)$algo');
    }

    for (final uc in blueprint.uniqueConstraints) {
      final cols = uc.columns.map((c) => '`$c`').join(', ');
      parts.add('  CONSTRAINT `${uc.name}` UNIQUE ($cols)');
    }

    for (final idx in blueprint.indexes) {
      final cols = idx.columns.map((c) => '`$c`').join(', ');
      if (idx.type == ColumnIndex.indexKey) {
        parts.add('  INDEX `${idx.name}` ($cols)');
      } else {
        parts.add(
          '  ${idx.type.name.toUpperCase()} INDEX `${idx.name}` ($cols)',
        );
      }
    }

    for (final fk in blueprint.foreignKeys) {
      final constraint = fk.constrained
          ? 'CONSTRAINT `FK_${blueprint.tableName}_${fk.referencesTable}` '
          : '';
      parts.add(
        '  ${constraint}FOREIGN KEY (`${fk.columnName}`) '
        'REFERENCES `${fk.referencesTable}` (`${fk.referencesColumn}`) '
        'ON UPDATE ${fk.onUpdate} ON DELETE ${fk.onDelete}',
      );
    }

    buf.write(parts.join(',\n'));
    buf.write('\n)');

    return [buf.toString()];
  }

  String _renderColumn(ColumnBlueprint col) {
    final buf = StringBuffer('`${col.name}` ');

    buf.write(_mysqlType(col));

    if (col.unsigned) buf.write(' UNSIGNED');
    if (col.zeroFill) buf.write(' ZEROFILL');

    buf.write(col.nullable ? ' NULL' : ' NOT NULL');

    if (col.unique) buf.write(' UNIQUE');

    if (col.defaultValue != null) {
      buf.write(' DEFAULT ${_renderDefault(col.defaultValue, col.name)}');
    }

    if (col.comment != null) {
      buf.write(' COMMENT ${formatValue(col.comment)}');
    }
    if (col.collation != null) buf.write(' COLLATE ${col.collation}');
    if (col.expression != null) {
      buf.write(' GENERATED ALWAYS AS (${col.expression})');
    }
    if (col.virtuality != null) buf.write(' ${col.virtuality}');
    if (col.autoIncrement) buf.write(' AUTO_INCREMENT');

    return buf.toString();
  }

  String _mysqlType(ColumnBlueprint col) {
    switch (col.type) {
      case ColumnType.bigInt:
        return col.length != null ? 'BIGINT(${col.length})' : 'BIGINT';
      case ColumnType.integer:
        return col.length != null ? 'INT(${col.length})' : 'INT';
      case ColumnType.tinyInt:
        return col.length != null ? 'TINYINT(${col.length})' : 'TINYINT';
      case ColumnType.smallInt:
        return col.length != null ? 'SMALLINT(${col.length})' : 'SMALLINT';
      case ColumnType.mediumInt:
        return col.length != null ? 'MEDIUMINT(${col.length})' : 'MEDIUMINT';
      case ColumnType.float:
        if (col.precision != null && col.scale != null) {
          return 'FLOAT(${col.precision},${col.scale})';
        }
        return 'FLOAT';
      case ColumnType.double:
        if (col.precision != null && col.scale != null) {
          return 'DOUBLE(${col.precision},${col.scale})';
        }
        return 'DOUBLE';
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
        return 'TEXT';
      case ColumnType.tinyText:
        return 'TINYTEXT';
      case ColumnType.mediumText:
        return 'MEDIUMTEXT';
      case ColumnType.longText:
        return 'LONGTEXT';
      case ColumnType.json:
        return 'JSON';
      case ColumnType.uuid:
        return 'CHAR(36)';
      case ColumnType.binary:
        return 'BINARY(${col.length ?? 50})';
      case ColumnType.varBinary:
        return 'VARBINARY(${col.length ?? 50})';
      case ColumnType.blob:
        return 'BLOB';
      case ColumnType.tinyBlob:
        return 'TINYBLOB';
      case ColumnType.mediumBlob:
        return 'MEDIUMBLOB';
      case ColumnType.longBlob:
        return 'LONGBLOB';
      case ColumnType.date:
        return 'DATE';
      case ColumnType.time:
        return 'TIME';
      case ColumnType.year:
        return 'YEAR';
      case ColumnType.dateTime:
        return 'DATETIME';
      case ColumnType.timestamp:
        return 'TIMESTAMP';
      case ColumnType.point:
        return 'POINT';
      case ColumnType.lineString:
        return 'LINESTRING';
      case ColumnType.polygon:
        return 'POLYGON';
      case ColumnType.geometry:
        return 'GEOMETRY';
      case ColumnType.multiPoint:
        return 'MULTIPOINT';
      case ColumnType.multiLineString:
        return 'MULTILINESTRING';
      case ColumnType.multiPolygon:
        return 'MULTIPOLYGON';
      case ColumnType.geometryCollection:
        return 'GEOMETRYCOLLECTION';
      case ColumnType.enumType:
        final vals = col.enumValues?.map(formatValue).join(', ') ?? '';
        return 'ENUM($vals)';
      case ColumnType.setType:
        final vals = col.setValues?.map(formatValue).join(', ') ?? '';
        return 'SET($vals)';
      case ColumnType.boolean:
        return 'TINYINT(1)';
      case ColumnType.bit:
        return 'BIT(${col.length ?? 1})';
    }
  }

  String _renderDefault(dynamic value, String columnName) {
    final funcRegex = RegExp(
      r'^(CURRENT_TIMESTAMP|NOW\(\)|UUID\(\)|RAND\(\))$',
      caseSensitive: false,
    );
    final str = value.toString();
    if (funcRegex.hasMatch(str)) {
      final result = str;
      if (columnName == 'updated_at' &&
          str.toUpperCase() == 'CURRENT_TIMESTAMP') {
        return '$result ON UPDATE CURRENT_TIMESTAMP';
      }
      return result;
    }
    if (value is int || value is bool) return '$value';
    return "'$value'";
  }

  @override
  List<String> renderAlterAddColumns(
    String table,
    TableBlueprint changes, {
    String afterColumn = '',
    String beforeColumn = '',
  }) {
    if (beforeColumn.isNotEmpty) {
      throw UnsupportedError(
        'MySQL has no BEFORE clause for ADD COLUMN. Use afterColumn with the '
        'preceding column instead.',
      );
    }

    final clauses = <String>[];

    for (final col in changes.columns) {
      var clause = 'ADD COLUMN ${_renderColumn(col)}';
      if (afterColumn.isNotEmpty) clause += ' AFTER `$afterColumn`';
      clauses.add(clause);
    }

    if (changes.primaryKey != null) {
      clauses.add('ADD PRIMARY KEY (`${changes.primaryKey}`)');
    }

    for (final uc in changes.uniqueConstraints) {
      final cols = uc.columns.map((c) => '`$c`').join(', ');
      clauses.add('ADD CONSTRAINT `${uc.name}` UNIQUE ($cols)');
    }

    for (final idx in changes.indexes) {
      final cols = idx.columns.map((c) => '`$c`').join(', ');
      if (idx.type == ColumnIndex.indexKey) {
        clauses.add('ADD INDEX `${idx.name}` ($cols)');
      } else {
        clauses.add(
          'ADD ${idx.type.name.toUpperCase()} INDEX `${idx.name}` ($cols)',
        );
      }
    }

    for (final fk in changes.foreignKeys) {
      final constraint = fk.constrained
          ? 'CONSTRAINT `FK_${table}_${fk.referencesTable}` '
          : '';
      clauses.add(
        'ADD ${constraint}FOREIGN KEY (`${fk.columnName}`) '
        'REFERENCES `${fk.referencesTable}` (`${fk.referencesColumn}`) '
        'ON UPDATE ${fk.onUpdate} ON DELETE ${fk.onDelete}',
      );
    }

    if (clauses.isEmpty) return [];

    final buf = StringBuffer('ALTER TABLE `$table`\n');
    for (var i = 0; i < clauses.length; i++) {
      final sep = i == clauses.length - 1 ? '' : ',';
      buf.writeln('  ${clauses[i]}$sep');
    }
    return [buf.toString().trimRight()];
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
    final options = <String>[];
    if (engine != null) options.add('ENGINE=$engine');
    if (charset != null) options.add('DEFAULT CHARSET=$charset');
    if (collation != null) options.add('COLLATE=$collation');
    if (comment != null) options.add('COMMENT=${formatValue(comment)}');
    if (autoIncrement != null) options.add('AUTO_INCREMENT=$autoIncrement');

    if (options.isEmpty) return const [];
    return ['ALTER TABLE ${escapeIdentifier(tableName)} ${options.join(', ')}'];
  }

  @override
  List<String> renderDropTable(String tableName, {bool ifExists = false}) {
    final drop = ifExists ? 'DROP TABLE IF EXISTS' : 'DROP TABLE';
    // Separate statements: the MySQL wire protocol rejects several
    // semicolon-joined statements in a single execute().
    return [
      'SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0',
      '$drop `$tableName`',
      'SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS',
    ];
  }

  @override
  List<String> renderDropColumn(String tableName, String columnName) {
    return ['ALTER TABLE `$tableName` DROP COLUMN `$columnName`'];
  }

  @override
  List<String> renderRenameColumn(
    String tableName,
    String oldName,
    String newName,
  ) {
    return ['ALTER TABLE `$tableName` RENAME COLUMN `$oldName` TO `$newName`'];
  }

  @override
  List<String> renderRenameTable(String oldName, String newName) {
    return ['RENAME TABLE `$oldName` TO `$newName`'];
  }

  @override
  List<String> renderAddIndex(String tableName, IndexBlueprint index) {
    final cols = index.columns.map((c) => '`$c`').join(', ');
    if (index.type == ColumnIndex.unique) {
      return ['CREATE UNIQUE INDEX `${index.name}` ON `$tableName` ($cols)'];
    }
    if (index.type == ColumnIndex.fulltext) {
      return ['CREATE FULLTEXT INDEX `${index.name}` ON `$tableName` ($cols)'];
    }
    if (index.type == ColumnIndex.spatial) {
      return ['CREATE SPATIAL INDEX `${index.name}` ON `$tableName` ($cols)'];
    }
    return ['CREATE INDEX `${index.name}` ON `$tableName` ($cols)'];
  }

  @override
  List<String> renderDropIndex(String tableName, String indexName) {
    return ['DROP INDEX `$indexName` ON `$tableName`'];
  }
}
