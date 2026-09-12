enum ColumnType {
  bigInt,
  integer,
  tinyInt,
  smallInt,
  mediumInt,
  float,
  double,
  decimal,
  varchar,
  char,
  text,
  tinyText,
  mediumText,
  longText,
  json,
  uuid,
  binary,
  varBinary,
  blob,
  tinyBlob,
  mediumBlob,
  longBlob,
  date,
  time,
  year,
  dateTime,
  timestamp,
  point,
  lineString,
  polygon,
  geometry,
  multiPoint,
  multiLineString,
  multiPolygon,
  geometryCollection,
  enumType,
  setType,
  boolean,
  bit,
}

class ColumnBlueprint {
  final String name;
  final ColumnType type;
  final bool nullable;
  final int? length;
  final int? precision;
  final int? scale;
  final bool unsigned;
  final bool zeroFill;
  final dynamic defaultValue;
  final String? comment;
  final String? collation;
  final String? charset;
  final String? expression;
  final String? virtuality;
  final bool autoIncrement;
  final bool unique;
  final List<String>? enumValues;
  final List<String>? setValues;

  const ColumnBlueprint({
    required this.name,
    required this.type,
    this.nullable = true,
    this.length,
    this.precision,
    this.scale,
    this.unsigned = false,
    this.zeroFill = false,
    this.defaultValue,
    this.comment,
    this.collation,
    this.charset,
    this.expression,
    this.virtuality,
    this.autoIncrement = false,
    this.unique = false,
    this.enumValues,
    this.setValues,
  });
}
