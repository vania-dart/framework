import '../../enum/column_index.dart';
import '../blueprint/column_blueprint.dart';
import '../blueprint/table_blueprint.dart';
import '../contracts/schema_interface.dart';

class Schema implements SchemaInterface {
  final List<ColumnBlueprint> _columns = [];
  final List<ForeignKeyBlueprint> _foreignKeyBlueprints = [];
  final List<IndexBlueprint> _indexBlueprints = [];
  final List<UniqueConstraintBlueprint> _uniqueConstraintBlueprints = [];
  final List<dynamic> _columnDefinitions = [];
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
    _columns.add(
      ColumnBlueprint(
        name: name,
        type: _parseColumnType(type),
        nullable: nullable,
        length: length is int ? length : null,
        precision: _extractPrecision(type),
        scale: _extractScale(type),
        unsigned: unsigned,
        zeroFill: zeroFill,
        defaultValue: defaultValue,
        comment: comment,
        collation: collation,
        expression: expression,
        virtuality: virtuality,
        autoIncrement: increment,
        unique: unique,
        enumValues: _extractEnumValues(type),
        setValues: _extractSetValues(type),
      ),
    );
  }

  void addColumnBlueprint(ColumnBlueprint blueprint) {
    _columns.add(blueprint);
  }

  ColumnType _parseColumnType(String rawType) {
    final upper = rawType
        .toUpperCase()
        .replaceAll(RegExp(r'\(.*\)'), '')
        .trim();
    switch (upper) {
      case 'BIGINT':
        return ColumnType.bigInt;
      case 'INT':
      case 'INTEGER':
        return ColumnType.integer;
      case 'TINYINT':
        return ColumnType.tinyInt;
      case 'SMALLINT':
        return ColumnType.smallInt;
      case 'MEDIUMINT':
        return ColumnType.mediumInt;
      case 'FLOAT':
        return ColumnType.float;
      case 'DOUBLE':
        return ColumnType.double;
      case 'DECIMAL':
        return ColumnType.decimal;
      case 'VARCHAR':
        return ColumnType.varchar;
      case 'CHAR':
        return ColumnType.char;
      case 'TEXT':
        return ColumnType.text;
      case 'TINYTEXT':
        return ColumnType.tinyText;
      case 'MEDIUMTEXT':
        return ColumnType.mediumText;
      case 'LONGTEXT':
        return ColumnType.longText;
      case 'JSON':
        return ColumnType.json;
      case 'UUID':
        return ColumnType.uuid;
      case 'BINARY':
        return ColumnType.binary;
      case 'VARBINARY':
        return ColumnType.varBinary;
      case 'BLOB':
        return ColumnType.blob;
      case 'TINYBLOB':
        return ColumnType.tinyBlob;
      case 'MEDIUMBLOB':
        return ColumnType.mediumBlob;
      case 'LONGBLOB':
        return ColumnType.longBlob;
      case 'DATE':
        return ColumnType.date;
      case 'TIME':
        return ColumnType.time;
      case 'YEAR':
        return ColumnType.year;
      case 'DATETIME':
        return ColumnType.dateTime;
      case 'TIMESTAMP':
        return ColumnType.timestamp;
      case 'POINT':
        return ColumnType.point;
      case 'LINESTRING':
        return ColumnType.lineString;
      case 'POLYGON':
        return ColumnType.polygon;
      case 'GEOMETRY':
        return ColumnType.geometry;
      case 'MULTIPOINT':
        return ColumnType.multiPoint;
      case 'MULTILINESTRING':
        return ColumnType.multiLineString;
      case 'MULTIPOLYGON':
        return ColumnType.multiPolygon;
      case 'GEOMETRYCOLLECTION':
        return ColumnType.geometryCollection;
      case 'BIT':
        return ColumnType.bit;
      case 'BOOLEAN':
      case 'BOOL':
        return ColumnType.boolean;
      default:
        if (upper.startsWith('ENUM')) return ColumnType.enumType;
        if (upper.startsWith('SET')) return ColumnType.setType;
        return ColumnType.varchar;
    }
  }

  int? _extractPrecision(String type) {
    final match = RegExp(r'\((\d+)\s*,\s*(\d+)\)').firstMatch(type);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  int? _extractScale(String type) {
    final match = RegExp(r'\((\d+)\s*,\s*(\d+)\)').firstMatch(type);
    return match != null ? int.tryParse(match.group(2)!) : null;
  }

  List<String>? _extractEnumValues(String type) {
    if (!type.toUpperCase().startsWith('ENUM')) return null;
    final match = RegExp(
      r"ENUM\((.+)\)",
      caseSensitive: false,
    ).firstMatch(type);
    if (match == null) return null;
    return match
        .group(1)!
        .split(',')
        .map((v) => v.trim().replaceAll("'", ''))
        .toList();
  }

  List<String>? _extractSetValues(String type) {
    if (!type.toUpperCase().startsWith('SET')) return null;
    final match = RegExp(r"SET\((.+)\)", caseSensitive: false).firstMatch(type);
    if (match == null) return null;
    return match
        .group(1)!
        .split(',')
        .map((v) => v.trim().replaceAll("'", ''))
        .toList();
  }

  @override
  void primary(String columnName, [String algorithm = 'BTREE']) {
    _primaryField = columnName;
    _primaryAlgorithm = algorithm;
  }

  @override
  void index(ColumnIndex type, String name, List<String> columns) {
    _indexBlueprints.add(
      IndexBlueprint(name: name, columns: columns, type: type),
    );
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
    _foreignKeyBlueprints.add(
      ForeignKeyBlueprint(
        columnName: columnName,
        referencesTable: referencesTable,
        referencesColumn: referencesColumn,
        onUpdate: onUpdate,
        onDelete: onDelete,
        constrained: constrained,
      ),
    );
  }

  @override
  List<String> get queries =>
      List.unmodifiable(_columns.map((c) => c.name).toList());

  @override
  List<String> get foreignKeys => List.unmodifiable(
    _foreignKeyBlueprints.map((f) => f.columnName).toList(),
  );

  @override
  List<String> get indexes =>
      List.unmodifiable(_indexBlueprints.map((i) => i.name).toList());

  @override
  String get primaryField => _primaryField;

  @override
  String get primaryAlgorithm => _primaryAlgorithm;

  String get tableName => _tableName;

  List<ColumnBlueprint> get columns => List.unmodifiable(_columns);

  @override
  void reset() {
    _columns.clear();
    _foreignKeyBlueprints.clear();
    _indexBlueprints.clear();
    _uniqueConstraintBlueprints.clear();
    _columnDefinitions.clear();
    _primaryField = '';
    _primaryAlgorithm = '';
    _tableName = '';
  }

  void addCompositeUniqueConstraint(
    String constraintName,
    List<String> columns,
  ) {
    final existing = _uniqueConstraintBlueprints.indexWhere(
      (c) => c.name == constraintName,
    );
    if (existing >= 0) {
      final old = _uniqueConstraintBlueprints[existing];
      _uniqueConstraintBlueprints[existing] = UniqueConstraintBlueprint(
        name: constraintName,
        columns: [...old.columns, ...columns],
      );
    } else {
      _uniqueConstraintBlueprints.add(
        UniqueConstraintBlueprint(
          name: constraintName,
          columns: List.from(columns),
        ),
      );
    }
  }

  void addCompositeIndex(
    String indexName,
    String columnName,
    ColumnIndex type,
  ) {
    final existing = _indexBlueprints.indexWhere((i) => i.name == indexName);
    if (existing >= 0) {
      final old = _indexBlueprints[existing];
      _indexBlueprints[existing] = IndexBlueprint(
        name: indexName,
        columns: [...old.columns, columnName],
        type: type,
      );
    } else {
      _indexBlueprints.add(
        IndexBlueprint(name: indexName, columns: [columnName], type: type),
      );
    }
  }

  @override
  TableBlueprint toBlueprint() {
    _finalizeColumnDefinitions();

    return TableBlueprint(
      tableName: _tableName,
      columns: List.unmodifiable(_columns),
      primaryKey: _primaryField.isNotEmpty ? _primaryField : null,
      primaryAlgorithm: _primaryAlgorithm,
      indexes: List.unmodifiable(_indexBlueprints),
      foreignKeys: List.unmodifiable(_foreignKeyBlueprints),
      uniqueConstraints: List.unmodifiable(_uniqueConstraintBlueprints),
    );
  }

  String generateDropTableSql(String tableName, {bool ifExists = false}) {
    String dropClause = ifExists ? 'DROP TABLE IF EXISTS' : 'DROP TABLE';
    return '$dropClause `$tableName`';
  }
}
