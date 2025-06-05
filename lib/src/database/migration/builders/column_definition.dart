import '../../../enum/column_index.dart';
import 'schema.dart';

class ColumnDefinition {
  final Schema _schema;
  final String _name;
  final String _type;

  bool _nullable = true;
  dynamic _length;
  bool _unsigned = false;
  bool _zeroFill = false;
  dynamic _defaultValue;
  String? _comment;
  String? _collation;
  String? _charset;
  String? _expression;
  String? _virtuality;
  bool _increment = false;
  bool _unique = false;
  String? _uniqueConstraintName;
  String? _indexName;
  ColumnIndex _indexType = ColumnIndex.indexKey;

  String? _foreignTable;
  String? _foreignColumn;
  String? _onUpdate;
  String? _onDelete;

  bool _isFinalized = false;

  ColumnDefinition(this._schema, this._name, this._type) {
    _schema.registerColumnDefinition(this);
  }

  /// Set column as NOT NULL
  ColumnDefinition notNull() {
    _nullable = false;
    return this;
  }

  /// Set column as NULLABLE
  ColumnDefinition nullable() {
    _nullable = true;
    return this;
  }

  /// Set column length/size
  ColumnDefinition length(int length) {
    _length = length;
    return this;
  }

  /// Set column as UNSIGNED (for numeric types)
  ColumnDefinition unsigned() {
    _unsigned = true;
    return this;
  }

  /// Set column as ZEROFILL
  ColumnDefinition zeroFill() {
    _zeroFill = true;
    return this;
  }

  /// Set default value
  ColumnDefinition defaultTo(dynamic value) {
    _defaultValue = value;
    return this;
  }

  /// Set default to CURRENT_TIMESTAMP
  ColumnDefinition defaultToCurrent() {
    _defaultValue = 'CURRENT_TIMESTAMP';
    return this;
  }

  /// Set column comment
  ColumnDefinition comment(String comment) {
    _comment = comment;
    return this;
  }

  /// Set column collation
  ColumnDefinition collate(String collation) {
    _collation = collation;
    return this;
  }

  /// Set column charset - NOW PROPERLY USED!
  ColumnDefinition charset(String charset) {
    _charset = charset;
    return this;
  }

  /// Set column as AUTO_INCREMENT
  ColumnDefinition autoIncrement() {
    _increment = true;
    return this;
  }

  /// Set column as UNIQUE
  ColumnDefinition unique([String? constraintName]) {
    if (constraintName != null) {
      _unique = false;
      _uniqueConstraintName = constraintName;
      _schema.addCompositeUniqueConstraint(constraintName, [_name]);
    } else {
      _unique = true;
      _uniqueConstraintName = null;
    }
    return this;
  }

  /// Add index to column - NOW PROPERLY USED!
  ColumnDefinition index(
      [String? indexName, ColumnIndex type = ColumnIndex.indexKey]) {
    _indexName = indexName ?? 'idx_${_schema.tableName}_$_name';
    _indexType = type;

    _schema.addCompositeIndex(_indexName!, _name, _indexType);
    return this;
  }

  ColumnDefinition foreignKey(String referencesTable, String referencesColumn,
      {String onUpdate = 'CASCADE', String onDelete = 'CASCADE'}) {
    _foreignTable = referencesTable;
    _foreignColumn = referencesColumn;
    _onUpdate = onUpdate;
    _onDelete = onDelete;

    _schema.foreign(
      _name,
      _foreignTable!,
      _foreignColumn!,
      onUpdate: _onUpdate ?? 'CASCADE',
      onDelete: _onDelete ?? 'CASCADE',
    );
    return this;
  }

  ColumnDefinition generated(String expression,
      {String virtuality = 'VIRTUAL'}) {
    _expression = expression;
    _virtuality = virtuality;
    return this;
  }

  void finalize() {
    if (!_isFinalized) {
      _isFinalized = true;
      _addColumnToSchema();
    }
  }

  void _addColumnToSchema() {
    String columnType = _type;
    if (_length != null) {
      columnType = '$_type($_length)';
    }

    String? finalComment = _comment;
    if (_charset != null) {
      String charsetInfo = 'charset: $_charset';
      finalComment =
          _comment != null ? '$_comment ($charsetInfo)' : charsetInfo;
    }

    bool shouldBeUnique = _unique && _uniqueConstraintName == null;

    _schema.addColumn(
      _name,
      columnType,
      nullable: _nullable,
      unsigned: _unsigned,
      zeroFill: _zeroFill,
      defaultValue: _defaultValue,
      comment: finalComment,
      collation: _collation,
      expression: _expression,
      virtuality: _virtuality,
      increment: _increment,
      unique: shouldBeUnique,
    );
  }
}
