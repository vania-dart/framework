import '../../enum/column_index.dart';
import '../blueprint/column_blueprint.dart';
import 'schema.dart';

class ColumnDefinition {
  final Schema _schema;
  final String _name;
  final ColumnType _type;

  bool _nullable = true;
  int? _length;
  final int? _precision;
  final int? _scale;
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
  final List<String>? _enumValues;
  final List<String>? _setValues;

  bool _isFinalized = false;

  ColumnDefinition(
    this._schema,
    this._name,
    this._type, {
    int? length,
    int? precision,
    int? scale,
    List<String>? enumValues,
    List<String>? setValues,
  }) : _length = length,
       _precision = precision,
       _scale = scale,
       _enumValues = enumValues,
       _setValues = setValues {
    _schema.registerColumnDefinition(this);
  }

  ColumnDefinition notNull() {
    _nullable = false;
    return this;
  }

  ColumnDefinition nullable() {
    _nullable = true;
    return this;
  }

  ColumnDefinition length(int length) {
    _length = length;
    return this;
  }

  ColumnDefinition unsigned() {
    _unsigned = true;
    return this;
  }

  ColumnDefinition zeroFill() {
    _zeroFill = true;
    return this;
  }

  ColumnDefinition defaultTo(dynamic value) {
    _defaultValue = value;
    return this;
  }

  ColumnDefinition defaultToCurrent() {
    _defaultValue = 'CURRENT_TIMESTAMP';
    return this;
  }

  ColumnDefinition comment(String comment) {
    _comment = comment;
    return this;
  }

  ColumnDefinition collate(String collation) {
    _collation = collation;
    return this;
  }

  ColumnDefinition charset(String charset) {
    _charset = charset;
    return this;
  }

  ColumnDefinition autoIncrement() {
    _increment = true;
    return this;
  }

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

  ColumnDefinition index([
    String? indexName,
    ColumnIndex type = ColumnIndex.indexKey,
  ]) {
    final name = indexName ?? 'idx_${_schema.tableName}_$_name';
    _schema.addCompositeIndex(name, _name, type);
    return this;
  }

  ColumnDefinition foreignKey(
    String referencesTable,
    String referencesColumn, {
    String onUpdate = 'CASCADE',
    String onDelete = 'CASCADE',
  }) {
    _schema.foreign(
      _name,
      referencesTable,
      referencesColumn,
      onUpdate: onUpdate,
      onDelete: onDelete,
    );
    return this;
  }

  ColumnDefinition generated(
    String expression, {
    String virtuality = 'VIRTUAL',
  }) {
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
    String? finalComment = _comment;
    if (_charset != null) {
      String charsetInfo = 'charset: $_charset';
      finalComment = _comment != null
          ? '$_comment ($charsetInfo)'
          : charsetInfo;
    }

    bool shouldBeUnique = _unique && _uniqueConstraintName == null;

    _schema.addColumnBlueprint(
      ColumnBlueprint(
        name: _name,
        type: _type,
        nullable: _nullable,
        length: _length,
        precision: _precision,
        scale: _scale,
        unsigned: _unsigned,
        zeroFill: _zeroFill,
        defaultValue: _defaultValue,
        comment: finalComment,
        collation: _collation,
        charset: _charset,
        expression: _expression,
        virtuality: _virtuality,
        autoIncrement: _increment,
        unique: shouldBeUnique,
        enumValues: _enumValues,
        setValues: _setValues,
      ),
    );
  }
}
