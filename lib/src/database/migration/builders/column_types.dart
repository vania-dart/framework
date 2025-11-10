import 'column_definition.dart';
import 'schema.dart';

export 'column_definition.dart';
export 'table_definition.dart';

extension ColumnTypes on Schema {
  /// Add an auto-incrementing primary key column
  ColumnDefinition id([String name = 'id']) {
    final definition = ColumnDefinition(
      this,
      name,
      'BIGINT',
    ).length(20).unsigned().autoIncrement().notNull();
    primary(name);
    return definition;
  }

  /// Add a big auto-incrementing column
  ColumnDefinition bigIncrements(String name) {
    final definition = ColumnDefinition(
      this,
      name,
      'BIGINT',
    ).length(20).unsigned().autoIncrement().notNull();
    return definition;
  }

  /// Create an integer column
  ColumnDefinition integer(String name) {
    return ColumnDefinition(this, name, 'INT').length(10);
  }

  /// Create a tiny integer column
  ColumnDefinition tinyInt(String name) {
    return ColumnDefinition(this, name, 'TINYINT').length(1);
  }

  /// Create a small integer column
  ColumnDefinition smallInt(String name) {
    return ColumnDefinition(this, name, 'SMALLINT').length(5);
  }

  /// Create a medium integer column
  ColumnDefinition mediumInt(String name) {
    return ColumnDefinition(this, name, 'MEDIUMINT').length(8);
  }

  /// Create a big integer column
  ColumnDefinition bigInt(String name) {
    return ColumnDefinition(this, name, 'BIGINT').length(20);
  }

  /// Create a bit column
  ColumnDefinition bit(String name) {
    return ColumnDefinition(this, name, 'BIT').length(1);
  }

  /// Create a float column
  ColumnDefinition float(String name, {int? precision, int? scale}) {
    String type = 'FLOAT';
    if (precision != null && scale != null) {
      type = 'FLOAT($precision,$scale)';
    }
    return ColumnDefinition(this, name, type);
  }

  /// Create a double column
  ColumnDefinition double(String name, {int? precision, int? scale}) {
    String type = 'DOUBLE';
    if (precision != null && scale != null) {
      type = 'DOUBLE($precision,$scale)';
    }
    return ColumnDefinition(this, name, type);
  }

  /// Create a decimal column
  ColumnDefinition decimal(String name, {int? precision, int? scale}) {
    String type = 'DECIMAL';
    if (precision != null && scale != null) {
      type = 'DECIMAL($precision,$scale)';
    }
    return ColumnDefinition(this, name, type);
  }

  /// Create a string/varchar column
  ColumnDefinition string(String name) {
    return ColumnDefinition(this, name, 'VARCHAR').length(255);
  }

  /// Create a char column
  ColumnDefinition char(String name) {
    return ColumnDefinition(this, name, 'CHAR').length(50);
  }

  /// Create a tiny text column
  ColumnDefinition tinyText(String name) {
    return ColumnDefinition(this, name, 'TINYTEXT');
  }

  /// Create a text column
  ColumnDefinition text(String name) {
    return ColumnDefinition(this, name, 'TEXT');
  }

  /// Create a medium text column
  ColumnDefinition mediumText(String name) {
    return ColumnDefinition(this, name, 'MEDIUMTEXT');
  }

  /// Create a long text column
  ColumnDefinition longText(String name) {
    return ColumnDefinition(this, name, 'LONGTEXT');
  }

  /// Create a JSON column
  ColumnDefinition json(String name) {
    return ColumnDefinition(this, name, 'JSON');
  }

  /// Create a UUID column
  ColumnDefinition uuid(String name) {
    return ColumnDefinition(this, name, 'CHAR').length(36);
  }

  /// Create a binary column
  ColumnDefinition binary(String name) {
    return ColumnDefinition(this, name, 'BINARY').length(50);
  }

  /// Create a variable binary column
  ColumnDefinition varBinary(String name) {
    return ColumnDefinition(this, name, 'VARBINARY').length(50);
  }

  /// Create a tiny blob column
  ColumnDefinition tinyBlob(String name) {
    return ColumnDefinition(this, name, 'TINYBLOB');
  }

  /// Create a blob column
  ColumnDefinition blob(String name) {
    return ColumnDefinition(this, name, 'BLOB');
  }

  /// Create a medium blob column
  ColumnDefinition mediumBlob(String name) {
    return ColumnDefinition(this, name, 'MEDIUMBLOB');
  }

  /// Create a long blob column
  ColumnDefinition longBlob(String name) {
    return ColumnDefinition(this, name, 'LONGBLOB');
  }

  /// Create a date column
  ColumnDefinition date(String name) {
    return ColumnDefinition(this, name, 'DATE');
  }

  /// Create a time column
  ColumnDefinition time(String name) {
    return ColumnDefinition(this, name, 'TIME');
  }

  /// Create a year column
  ColumnDefinition year(String name) {
    return ColumnDefinition(this, name, 'YEAR');
  }

  /// Create a datetime column
  ColumnDefinition dateTime(String name) {
    return ColumnDefinition(this, name, 'DATETIME');
  }

  /// Create a timestamp column
  ColumnDefinition timeStamp(String name) {
    return ColumnDefinition(this, name, 'TIMESTAMP');
  }

  /// Create standard timestamps (created_at, updated_at)
  void timeStamps() {
    timeStamp('created_at').nullable();
    timeStamp('updated_at').nullable();
  }

  /// Create soft delete timestamp
  ColumnDefinition softDeletes([String name = 'deleted_at']) {
    return timeStamp(name).nullable();
  }

  /// Create a point geometry column
  ColumnDefinition point(String name) {
    return ColumnDefinition(this, name, 'POINT');
  }

  /// Create a line string geometry column
  ColumnDefinition lineString(String name) {
    return ColumnDefinition(this, name, 'LINESTRING');
  }

  /// Create a polygon geometry column
  ColumnDefinition polygon(String name) {
    return ColumnDefinition(this, name, 'POLYGON');
  }

  /// Create a geometry column
  ColumnDefinition geometry(String name) {
    return ColumnDefinition(this, name, 'GEOMETRY');
  }

  /// Create a multi-point geometry column
  ColumnDefinition multiPoint(String name) {
    return ColumnDefinition(this, name, 'MULTIPOINT');
  }

  /// Create a multi-line string geometry column
  ColumnDefinition multiLineString(String name) {
    return ColumnDefinition(this, name, 'MULTILINESTRING');
  }

  /// Create a multi-polygon geometry column
  ColumnDefinition multiPolygon(String name) {
    return ColumnDefinition(this, name, 'MULTIPOLYGON');
  }

  /// Create a geometry collection column
  ColumnDefinition geometryCollection(String name) {
    return ColumnDefinition(this, name, 'GEOMETRYCOLLECTION');
  }

  /// Create an enum column
  ColumnDefinition enumType(String name, List<String> values) {
    final enumValuesString = values.map((value) => "'$value'").join(', ');
    return ColumnDefinition(this, name, 'ENUM($enumValuesString)');
  }

  /// Create a set column
  ColumnDefinition setType(String name, List<String> values) {
    final setValuesString = values.map((value) => "'$value'").join(', ');
    return ColumnDefinition(this, name, 'SET($setValuesString)');
  }

  /// Create a boolean column
  ColumnDefinition boolean(String name) {
    return ColumnDefinition(this, name, 'TINYINT').length(1);
  }
}
