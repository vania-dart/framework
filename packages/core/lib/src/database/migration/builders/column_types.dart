import '../blueprint/column_blueprint.dart';
import 'column_definition.dart';
import 'schema.dart';

export 'column_definition.dart';
export 'table_definition.dart';

extension ColumnTypes on Schema {
  ColumnDefinition id([String name = 'id']) {
    final definition = ColumnDefinition(
      this,
      name,
      ColumnType.bigInt,
      length: 20,
    ).unsigned().autoIncrement().notNull();
    primary(name);
    return definition;
  }

  ColumnDefinition bigIncrements(String name) {
    final definition = ColumnDefinition(
      this,
      name,
      ColumnType.bigInt,
      length: 20,
    ).unsigned().autoIncrement().notNull();
    return definition;
  }

  ColumnDefinition integer(String name) {
    return ColumnDefinition(this, name, ColumnType.integer, length: 10);
  }

  ColumnDefinition tinyInt(String name) {
    return ColumnDefinition(this, name, ColumnType.tinyInt, length: 1);
  }

  ColumnDefinition smallInt(String name) {
    return ColumnDefinition(this, name, ColumnType.smallInt, length: 5);
  }

  ColumnDefinition mediumInt(String name) {
    return ColumnDefinition(this, name, ColumnType.mediumInt, length: 8);
  }

  ColumnDefinition bigInt(String name) {
    return ColumnDefinition(this, name, ColumnType.bigInt, length: 20);
  }

  ColumnDefinition bit(String name) {
    return ColumnDefinition(this, name, ColumnType.bit, length: 1);
  }

  ColumnDefinition float(String name, {int? precision, int? scale}) {
    return ColumnDefinition(
      this,
      name,
      ColumnType.float,
      precision: precision,
      scale: scale,
    );
  }

  ColumnDefinition double(String name, {int? precision, int? scale}) {
    return ColumnDefinition(
      this,
      name,
      ColumnType.double,
      precision: precision,
      scale: scale,
    );
  }

  ColumnDefinition decimal(String name, {int? precision, int? scale}) {
    return ColumnDefinition(
      this,
      name,
      ColumnType.decimal,
      precision: precision,
      scale: scale,
    );
  }

  ColumnDefinition string(String name) {
    return ColumnDefinition(this, name, ColumnType.varchar, length: 255);
  }

  ColumnDefinition char(String name) {
    return ColumnDefinition(this, name, ColumnType.char, length: 50);
  }

  ColumnDefinition tinyText(String name) {
    return ColumnDefinition(this, name, ColumnType.tinyText);
  }

  ColumnDefinition text(String name) {
    return ColumnDefinition(this, name, ColumnType.text);
  }

  ColumnDefinition mediumText(String name) {
    return ColumnDefinition(this, name, ColumnType.mediumText);
  }

  ColumnDefinition longText(String name) {
    return ColumnDefinition(this, name, ColumnType.longText);
  }

  ColumnDefinition json(String name) {
    return ColumnDefinition(this, name, ColumnType.json);
  }

  ColumnDefinition uuid(String name) {
    return ColumnDefinition(this, name, ColumnType.uuid, length: 36);
  }

  ColumnDefinition binary(String name) {
    return ColumnDefinition(this, name, ColumnType.binary, length: 50);
  }

  ColumnDefinition varBinary(String name) {
    return ColumnDefinition(this, name, ColumnType.varBinary, length: 50);
  }

  ColumnDefinition tinyBlob(String name) {
    return ColumnDefinition(this, name, ColumnType.tinyBlob);
  }

  ColumnDefinition blob(String name) {
    return ColumnDefinition(this, name, ColumnType.blob);
  }

  ColumnDefinition mediumBlob(String name) {
    return ColumnDefinition(this, name, ColumnType.mediumBlob);
  }

  ColumnDefinition longBlob(String name) {
    return ColumnDefinition(this, name, ColumnType.longBlob);
  }

  ColumnDefinition date(String name) {
    return ColumnDefinition(this, name, ColumnType.date);
  }

  ColumnDefinition time(String name) {
    return ColumnDefinition(this, name, ColumnType.time);
  }

  ColumnDefinition year(String name) {
    return ColumnDefinition(this, name, ColumnType.year);
  }

  ColumnDefinition dateTime(String name) {
    return ColumnDefinition(this, name, ColumnType.dateTime);
  }

  ColumnDefinition timeStamp(String name) {
    return ColumnDefinition(this, name, ColumnType.timestamp);
  }

  void timeStamps() {
    timeStamp('created_at').nullable();
    timeStamp('updated_at').nullable();
  }

  ColumnDefinition softDeletes([String name = 'deleted_at']) {
    return timeStamp(name).nullable();
  }

  ColumnDefinition point(String name) {
    return ColumnDefinition(this, name, ColumnType.point);
  }

  ColumnDefinition lineString(String name) {
    return ColumnDefinition(this, name, ColumnType.lineString);
  }

  ColumnDefinition polygon(String name) {
    return ColumnDefinition(this, name, ColumnType.polygon);
  }

  ColumnDefinition geometry(String name) {
    return ColumnDefinition(this, name, ColumnType.geometry);
  }

  ColumnDefinition multiPoint(String name) {
    return ColumnDefinition(this, name, ColumnType.multiPoint);
  }

  ColumnDefinition multiLineString(String name) {
    return ColumnDefinition(this, name, ColumnType.multiLineString);
  }

  ColumnDefinition multiPolygon(String name) {
    return ColumnDefinition(this, name, ColumnType.multiPolygon);
  }

  ColumnDefinition geometryCollection(String name) {
    return ColumnDefinition(this, name, ColumnType.geometryCollection);
  }

  ColumnDefinition enumType(String name, List<String> values) {
    return ColumnDefinition(
      this,
      name,
      ColumnType.enumType,
      enumValues: values,
    );
  }

  ColumnDefinition setType(String name, List<String> values) {
    return ColumnDefinition(this, name, ColumnType.setType, setValues: values);
  }

  ColumnDefinition boolean(String name) {
    return ColumnDefinition(this, name, ColumnType.boolean);
  }

  ColumnDefinition ipAddress(String name) {
    return ColumnDefinition(this, name, ColumnType.varchar, length: 45);
  }

  ColumnDefinition macAddress(String name) {
    return ColumnDefinition(this, name, ColumnType.varchar, length: 17);
  }
}
