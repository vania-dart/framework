import '../../../enum/column_index.dart';
import '../contracts/schema_interface.dart';

class Schema implements SchemaInterface {
  final List<String> _queries = [];
  final List<String> _foreignKeys = [];
  final List<String> _indexes = [];
  final List<dynamic> _columnDefinitions = [];
  final Map<String, List<String>> _compositeUniqueConstraints = {};
  final Map<String, Map<String, dynamic>> _compositeIndexes = {};
  String _primaryField = '';
  String _primaryAlgorithm = '';
  String _tableName = '';

  void setTableName(String tableName) {
    _tableName = tableName;
  }

  void registerColumnDefinition(dynamic columnDefinition) {
    _columnDefinitions.add(columnDefinition);
  }

  void _finalizeColumnDefinitions() {
    for (final columnDef in _columnDefinitions) {
      columnDef.finalize();
    }
    _columnDefinitions.clear();

    _addCompositeUniqueConstraints();

    _addCompositeIndexes();
  }

  void _addCompositeUniqueConstraints() {
    _compositeUniqueConstraints.forEach((constraintName, columns) {
      final constraint =
          'CONSTRAINT `$constraintName` UNIQUE (${columns.map((col) => '`$col`').join(', ')})';
      _indexes.add(constraint);
    });
  }

  void _addCompositeIndexes() {
    _compositeIndexes.forEach((indexName, indexData) {
      List<String> columns = indexData['columns'];
      ColumnIndex type = indexData['type'];

      if (type == ColumnIndex.indexKey) {
        _indexes.add(
            'INDEX `$indexName` (${columns.map((e) => "`$e`").join(', ')})');
      } else {
        _indexes.add(
            '${type.name} INDEX `$indexName` (${columns.map((e) => "`$e`").join(', ')})');
      }
    });
  }

  @override
  void addColumn(
    String name,
    String type, {
    bool nullable = false,
    dynamic length,
    bool unsigned = false,
    bool zeroFill = false,
    dynamic defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
    bool increment = false,
    bool unique = false,
  }) {
    final columnDefinition = StringBuffer('  `$name` $type');

    if (length != null) {
      columnDefinition.write('($length)');
    }

    if (unsigned) {
      columnDefinition.write(' UNSIGNED');
    }

    if (zeroFill) {
      columnDefinition.write(' ZEROFILL');
    }

    String nullableStr = nullable ? 'NULL' : 'NOT NULL';
    columnDefinition
        .write(' ' * (20 - columnDefinition.length % 20) + nullableStr);

    if (unique) {
      columnDefinition.write(' UNIQUE');
    }

    if (defaultValue != null) {
      RegExp funcRegex = RegExp(
          r'^(CURRENT_TIMESTAMP|NOW\(\)|UUID\(\)|RAND\(\))$',
          caseSensitive: false);
      if (funcRegex.hasMatch(defaultValue.toString())) {
        columnDefinition.write(" DEFAULT $defaultValue");

        if (name == 'updated_at' &&
            defaultValue.toString().toUpperCase() == 'CURRENT_TIMESTAMP') {
          columnDefinition.write(" ON UPDATE CURRENT_TIMESTAMP");
        }
      } else {
        if (defaultValue is int || defaultValue is bool) {
          columnDefinition.write(" DEFAULT $defaultValue");
        } else {
          columnDefinition.write(" DEFAULT '$defaultValue'");
        }
      }
    }

    if (comment != null) {
      columnDefinition.write(" COMMENT '$comment'");
    }

    if (collation != null) {
      columnDefinition.write(" COLLATE $collation");
    }

    if (expression != null) {
      columnDefinition.write(' GENERATED ALWAYS AS ($expression)');
    }

    if (virtuality != null) {
      columnDefinition.write(' $virtuality');
    }

    if (increment) {
      columnDefinition.write(' AUTO_INCREMENT');
    }

    _queries.add(columnDefinition.toString());
  }

  @override
  void primary(String columnName, [String algorithm = 'BTREE']) {
    _primaryField = columnName;
    _primaryAlgorithm = algorithm;
  }

  @override
  void index(ColumnIndex type, String name, List<String> columns) {
    if (type == ColumnIndex.indexKey) {
      _indexes.add('INDEX `$name` (${columns.map((e) => "`$e`").join(',')})');
    } else {
      _indexes.add(
          '${type.name.toUpperCase()} INDEX `$name` (${columns.map((e) => "`$e`").join(',')})');
    }
  }

  @override
  void foreign(
    String columnName,
    String referencesTable,
    String referencesColumn, {
    bool constrained = true,
    String onUpdate = 'CASCADE',
    String onDelete = 'CASCADE',
  }) {
    String constraint = '';
    if (constrained) {
      constraint = 'CONSTRAINT FK_${_tableName}_$referencesTable ';
    }

    final fk =
        '${constraint}FOREIGN KEY (`$columnName`) REFERENCES `$referencesTable` (`$referencesColumn`) ON UPDATE $onUpdate ON DELETE $onDelete';
    _foreignKeys.add(fk);
  }

  @override
  List<String> get queries => List.unmodifiable(_queries);

  @override
  List<String> get foreignKeys => List.unmodifiable(_foreignKeys);

  @override
  List<String> get indexes => List.unmodifiable(_indexes);

  @override
  String get primaryField => _primaryField;

  @override
  String get primaryAlgorithm => _primaryAlgorithm;

  String get tableName => _tableName;

  @override
  void reset() {
    _queries.clear();
    _foreignKeys.clear();
    _indexes.clear();
    _columnDefinitions.clear();
    _compositeUniqueConstraints.clear();
    _compositeIndexes.clear();
    _primaryField = '';
    _primaryAlgorithm = '';
    _tableName = '';
  }

  void addCompositeUniqueConstraint(
      String constraintName, List<String> columns) {
    if (_compositeUniqueConstraints.containsKey(constraintName)) {
      _compositeUniqueConstraints[constraintName]!.addAll(columns);
    } else {
      _compositeUniqueConstraints[constraintName] = List.from(columns);
    }
  }

  void addCompositeIndex(
      String indexName, String columnName, ColumnIndex type) {
    if (_compositeIndexes.containsKey(indexName)) {
      _compositeIndexes[indexName]!['columns'].add(columnName);
    } else {
      _compositeIndexes[indexName] = {
        'columns': [columnName],
        'type': type,
      };
    }
  }

  String generateCreateTableSql(String tableName, {bool ifNotExists = false}) {
    _finalizeColumnDefinitions();

    final query = StringBuffer();
    String createClause =
        ifNotExists ? 'CREATE TABLE IF NOT EXISTS' : 'CREATE TABLE';

    query.writeln('$createClause `$tableName` (');

    query.write(_queries.join(',\n'));

    if (_primaryField.isNotEmpty) {
      query.write(',\n  PRIMARY KEY (`$_primaryField`)');
    }

    if (_indexes.isNotEmpty) {
      for (String index in _indexes) {
        query.write(',\n  $index');
      }
    }

    if (_foreignKeys.isNotEmpty) {
      for (String fk in _foreignKeys) {
        query.write(',\n  $fk');
      }
    }

    query.write('\n)');

    return query.toString();
  }

  String generateCreateAlterSql(
    String tableName, {
    bool ifNotExists = false,
    String beforeColumn = '',
    String afterColumn = '',
  }) {
    _finalizeColumnDefinitions();

    final clauses = <String>[];

    for (final colDef in _queries) {
      var clause = 'ADD COLUMN ${colDef.trim()}';
      if (beforeColumn.isNotEmpty) clause += ' BEFORE `$beforeColumn`';
      if (afterColumn.isNotEmpty) clause += ' AFTER `$afterColumn`';
      clauses.add(clause);
    }

    if (_primaryField.isNotEmpty) {
      clauses.add('ADD PRIMARY KEY (`$_primaryField`)');
    }

    for (final idx in _indexes) {
      clauses.add('ADD $idx');
    }

    for (final fk in _foreignKeys) {
      clauses.add('ADD $fk');
    }

    final buffer = StringBuffer();
    buffer.writeln('ALTER TABLE `$tableName`');
    for (var i = 0; i < clauses.length; i++) {
      final sep = i == clauses.length - 1 ? '' : ',';
      buffer.writeln('  ${clauses[i]}$sep');
    }

    return buffer.toString();
  }

  String generateDropTableSql(String tableName, {bool ifExists = false}) {
    String dropClause = ifExists ? 'DROP TABLE IF EXISTS' : 'DROP TABLE';
    return '$dropClause `$tableName`';
  }
}
