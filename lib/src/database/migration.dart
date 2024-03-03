import 'dart:io';

import 'package:eloquent/eloquent.dart';
import 'package:meta/meta.dart';
import 'package:vania/vania.dart';

class MigrationConnection {
  static final MigrationConnection _singleton = MigrationConnection._internal();
  factory MigrationConnection() => _singleton;
  MigrationConnection._internal();
  Connection? dbConnection;
  DatabaseDriver? database;
  Future<void> setup(DatabaseConfig databaseConfig) async {
    database = databaseConfig.driver;
    try {
      await database?.init(databaseConfig);
      dbConnection = database!.connection;
    } on InvalidArgumentException catch (_) {
      print('Error establishing a database connection');
    } catch (e) {
      print(e);
      exit(0);
    }
  }

  Future<void> closeConnection() async {
    await dbConnection?.disconnect();
  }
}

class Migration {
  String tableName = '';
  List<String> queries = [];
  List<String> foreignKey = [];
  String primaryField = '';
  String primaryAlgorithm = '';
  List<String> indexes = [];

  @mustBeOverridden
  @mustCallSuper
  Future<void> up() async {
    if (MigrationConnection().dbConnection == null) {
      print('Database is not defined');
      throw 'Database is not defined';
    }
  }

  Future<void> createTable(String name, Function callback) async {
    try {
      final query = StringBuffer();
      tableName = name;
      callback();
      String index = indexes.isNotEmpty ? ',${indexes.join(',')}' : '';
      String foreig = foreignKey.isNotEmpty ? ',${foreignKey.join(',')}' : '';
      String primary = primaryField.isNotEmpty
          ? ',PRIMARY KEY (`$primaryField`) USING $primaryAlgorithm'
          : '';
      query.write(
          '''DROP TABLE IF EXISTS `$name`; CREATE TABLE `$name` (${queries.join(',')}$primary$index$foreig)''');

      if (MigrationConnection().database?.driver == 'Postgresql') {
        await MigrationConnection()
            .dbConnection
            ?.execute(_mysqlToPosgresqlMapper(query.toString()));
      } else {
        await MigrationConnection()
            .dbConnection
            ?.execute(query.toString().replaceAll(RegExp(r',\s?\)'), ')'));
      }

      print(
          ' Create $name table....................................\x1B[32mDONE\x1B[0m');
    } catch (e) {
      print(e);
      exit(0);
    }
  }

  Future<void> createTableNotExists(String name, Function callback) async {
    try {
      final query = StringBuffer();
      tableName = name;
      callback();
      String index = indexes.isNotEmpty ? ',${indexes.join(',')}' : '';
      String foreig = foreignKey.isNotEmpty ? ',${foreignKey.join(',')}' : '';
      String primary = primaryField.isNotEmpty
          ? ',PRIMARY KEY (`$primaryField`) USING $primaryAlgorithm'
          : '';
      query.write(
          '''CREATE TABLE IF NOT EXISTS `$name` (${queries.join(',')}$primary$index$foreig)''');

      if (MigrationConnection().database?.driver == 'Postgresql') {
        await MigrationConnection()
            .dbConnection
            ?.execute(_mysqlToPosgresqlMapper(query.toString()));
      } else {
        await MigrationConnection()
            .dbConnection
            ?.execute(query.toString().replaceAll(RegExp(r',\s?\)'), ')'));
      }

      print(
          ' Create $name table....................................\x1B[32mDONE\x1B[0m');
    } catch (e) {
      print(e);
      exit(0);
    }
  }

  Future<void> dropTable(String name) async {
    String query = 'DROP TABLE IF EXISTS "$name";';

    await MigrationConnection().dbConnection?.execute(query.toString());
    print(
        ' Dropping $name table....................................\x1B[32mDONE\x1B[0m');
  }

  void addColumn(
    String name,
    String type, {
    bool nullable = false,
    dynamic length,
    bool unsigned = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
    bool increment = false,
  }) {
    final columnDefinition = StringBuffer('`$name` $type');

    if (length != null) {
      columnDefinition.write('($length)');
    }

    if (unsigned) {
      columnDefinition.write(' UNSIGNED');
    }

    if (zeroFill) {
      columnDefinition.write(' ZEROFILL');
    }

    columnDefinition.write(nullable ? ' NULL' : ' NOT NULL');

    if (defaultValue != null) {
      columnDefinition.write(" DEFAULT '$defaultValue'");
    }

    if (comment != null) {
      columnDefinition.write(" COMMENT '$comment'");
    }

    if (collation != null) {
      columnDefinition.write(" COLLATE '$collation'");
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

    queries.add(columnDefinition.toString());
  }

  void primary(String columnName, [String algorithm = 'BTREE']) {
    primaryField = columnName;
    primaryAlgorithm = algorithm;
  }

  void index(ColumnIndex type, String name, List<String> columns) {
    if (type == ColumnIndex.indexKey) {
      indexes.add('INDEX `$name` (${columns.map((e) => "`$e`").join(',')})');
    } else {
      indexes.add(
          '${type.name} INDEX `$name` (${columns.map((e) => "`$e`").join(',')})');
    }
  }

  void foreign(
    String columnName,
    String referencesTable,
    String referencesColumn, {
    bool constrained = false,
    String onUpdate = 'NO ACTION',
    String onDelete = 'NO ACTION',
  }) {
    String constraint = '';
    if (constrained) {
      constraint = 'CONSTRAINT FK_${tableName}_$referencesTable';
    }

    final fk =
        '$constraint FOREIGN KEY (`$columnName`) REFERENCES `$referencesTable` (`$referencesColumn`) ON UPDATE $onUpdate ON DELETE $onDelete';
    foreignKey.add(fk);
  }

  void id() {
    bigIncrements('id');
    primary('id');
  }

  void bigIncrements(
    String name, {
    bool nullable = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'BIGINT',
      nullable: nullable,
      length: 20,
      unsigned: true,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
      increment: true,
    );
  }

  void integer(
    String name, {
    bool nullable = false,
    int length = 10,
    bool unsigned = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
    bool increment = false,
  }) {
    addColumn(
      name,
      'INT',
      nullable: nullable,
      length: length,
      unsigned: unsigned,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
      increment: increment,
    );
  }

  void tinyInt(
    String name, {
    bool nullable = false,
    int length = 1,
    bool unsigned = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
    bool increment = false,
  }) {
    addColumn(
      name,
      'TINYINT',
      nullable: nullable,
      length: length,
      unsigned: unsigned,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
      increment: increment,
    );
  }

  void smallInt(
    String name, {
    bool nullable = false,
    int length = 1,
    bool unsigned = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
    bool increment = false,
  }) {
    addColumn(
      name,
      'SMALLINT',
      nullable: nullable,
      length: length,
      unsigned: unsigned,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
      increment: increment,
    );
  }

  void mediumInt(
    String name, {
    bool nullable = false,
    int length = 10,
    bool unsigned = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
    bool increment = false,
  }) {
    addColumn(
      name,
      'MEDIUMINT',
      nullable: nullable,
      length: length,
      unsigned: unsigned,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
      increment: increment,
    );
  }

  void bigInt(
    String name, {
    bool nullable = false,
    int length = 20,
    bool unsigned = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
    bool increment = false,
  }) {
    addColumn(
      name,
      'BIGINT',
      nullable: nullable,
      length: length,
      unsigned: unsigned,
      zeroFill: zeroFill,
      increment: increment,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void bit(
    String name, {
    bool nullable = false,
    bool unsigned = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'BIT',
      nullable: nullable,
      unsigned: unsigned,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void float(
    String name, {
    bool nullable = false,
    int? precision,
    int? scale,
    bool unsigned = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'FLOAT($precision,$scale)',
      nullable: nullable,
      unsigned: unsigned,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void double(
    String name, {
    bool nullable = false,
    int? precision,
    int? scale,
    bool unsigned = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'DOUBLE($precision,$scale)',
      nullable: nullable,
      unsigned: unsigned,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void decimal(
    String name, {
    bool nullable = false,
    int? precision,
    int? scale,
    bool unsigned = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'DECIMAL($precision,$scale)',
      nullable: nullable,
      unsigned: unsigned,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void string(
    String name, {
    bool nullable = false,
    int length = 255,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'VARCHAR',
      nullable: nullable,
      length: length,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void char(
    String name, {
    bool nullable = false,
    int length = 50,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'CHAR',
      nullable: nullable,
      length: length,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void tinyText(
    String name, {
    bool nullable = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'TINYTEXT',
      nullable: nullable,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void text(
    String name, {
    bool nullable = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'TEXT',
      nullable: nullable,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void mediumText(
    String name, {
    bool nullable = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'MEDIUMTEXT',
      nullable: nullable,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void longText(
    String name, {
    bool nullable = false,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'LONGTEXT',
      nullable: nullable,
      zeroFill: zeroFill,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void json(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'JSON',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void uuid(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'UUID',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void binary(
    String name, {
    bool nullable = false,
    int length = 50,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'BINARY',
      nullable: nullable,
      length: length,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      zeroFill: zeroFill,
      virtuality: virtuality,
    );
  }

  void varBinary(
    String name, {
    bool nullable = false,
    int length = 50,
    bool zeroFill = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'VARBINARY',
      nullable: nullable,
      length: length,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      zeroFill: zeroFill,
      virtuality: virtuality,
    );
  }

  void tinyBlob(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'TINYBLOB',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void blob(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'BLOB',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void mediumBlob(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'MEDIUMBLOB',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void longBlob(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'LONGBLOB',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void date(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'DATE',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void time(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'TIME',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void year(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'YEAR',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void dateTime(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'DATETIME',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void timeStamp(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'TIMESTAMP',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void softDeletes(String name) {
    timeStamp(
      name,
      nullable: true,
    );
  }

  void point(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'POINT',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void lineString(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'LINESTRING',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void polygon(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'POLYGON',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void geometry(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'GEOMETRY',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void multiPoint(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'MULTIPOINT',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void multiLineString(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'MULTILINESTRING',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void multiPolygon(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'MULTIPOLYGON',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void geometryCollection(
    String name, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    addColumn(
      name,
      'GEOMETRYCOLLECTION',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void enumType(
    String name,
    List<String> enumValues, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    final enumValuesString = enumValues.map((value) => "'$value'").join(', ');
    addColumn(
      name,
      'ENUM($enumValuesString)',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  void setType(
    String name,
    List<String> setValues, {
    bool nullable = false,
    String? defaultValue,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
  }) {
    final setValuesString = setValues.map((value) => "'$value'").join(', ');
    addColumn(
      name,
      'SET($setValuesString)',
      nullable: nullable,
      defaultValue: defaultValue,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
    );
  }

  /// Mapper for mysql to postgresql query
  String _mysqlToPosgresqlMapper(String queryStr) {
    List strList = queryStr.split(',');
    List<String> queryList = [];
    for (String str in strList) {
      str = _mysqlAiToSerial(str);

      String query = str
          .replaceAll(RegExp(r"BIGINT\((\d+)\)"), "BIGINT")
          .replaceAll(
              RegExp(r"(^|\s|,)INT\((\d+)\)", caseSensitive: false), " INTEGER")
          .replaceAll(RegExp(r"(^|\s|,)INTEGER\((\d+)\)", caseSensitive: false),
              " INTEGER")
          .replaceAll(
              RegExp(r"MEDIUMINT\((\d+)\)", caseSensitive: false), "INTEGER")
          .replaceAll(
              RegExp(r"SMALLINT\((\d+)\)", caseSensitive: false), "SMALLINT")
          .replaceAll(
              RegExp(r"TINYINT\((\d+)\)", caseSensitive: false), "SMALLINT")
          .replaceAll(RegExp(r"BINARY\((\d+)\)", caseSensitive: false), "BYTEA")
          .replaceAll(RegExp(r"BIT\((\d+)\)", caseSensitive: false), "BOOLEAN")
          .replaceAllMapped(
              RegExp(r"VARCHAR\((\d+)\)"), (match) => "VARCHAR(${match[1]})")
          .replaceAllMapped(RegExp(r"VARCHARACTER\((\d+)\)"),
              (match) => "CHARACTER(${match[1]})")
          .replaceAllMapped(RegExp(r"FLOAT\((\d+)\)"), (match) => "REAL")
          .replaceAll(
              RegExp(r"DATETIME\((\d+)\)", caseSensitive: false), "TIMESTAMP")
          .replaceAll(RegExp(r"DOUBLE\((\d+)\)", caseSensitive: false),
              "DOUBLE PRECISION")
          .replaceAll(RegExp(r"TINYBLOB", caseSensitive: false), "BYTEA")
          .replaceAll(RegExp(r"VARBYTEA", caseSensitive: false), "BYTEA")
          .replaceAll(RegExp(r"BLOB", caseSensitive: false), "BYTEA")
          .replaceAll(RegExp(r"MEDIUMBLOB", caseSensitive: false), "BYTEA")
          .replaceAll(RegExp(r"LONGBLOB", caseSensitive: false), "BYTEA")
          .replaceAll(RegExp(r"MEDIUMBYTEA", caseSensitive: false), "BYTEA")
          .replaceAll(RegExp(r"LONGBYTEA", caseSensitive: false), "BYTEA")
          .replaceAll(RegExp(r"TINYTEXT", caseSensitive: false), "TEXT")
          .replaceAll(RegExp(r"MEDIUMTEXT", caseSensitive: false), "TEXT")
          .replaceAll(
              RegExp(r"LONGTEXT\((\d+)\)", caseSensitive: false), "TEXT")
          .replaceAll(RegExp(r"LINESTRING", caseSensitive: false), "LINE")
          .replaceAll(RegExp(r"TIME\((\d+)\)", caseSensitive: false), "TIME")
          .replaceAll(RegExp(r"TIME\((\d+)\)", caseSensitive: false), "TIME")
          .replaceAll(
              RegExp(r"VARBINARY\((\d+)\)", caseSensitive: false), "BYTEA")
          .replaceAll(
              RegExp(r"VARBINARY\((\d+)\)", caseSensitive: false), "BYTEA")
          .replaceAll(
              RegExp(r"ENUM\((?:'[^']*'(?:\s*,\s*'[^']*')*)\)",
                  caseSensitive: false),
              "VARCHAR")
          .replaceAll(RegExp(r"COLLATE '[\w\d_-]+'", caseSensitive: false), "")
          .replaceAll(
              RegExp(
                  r"DEFAULT\s+('(?:[^'\\]|\\.)*'|NULL|CURRENT_TIMESTAMP(?:\s+ON\s+UPDATE\s+CURRENT_TIMESTAMP)?|\d+)",
                  caseSensitive: false),
              "")
          .replaceAll('`', '"');

      queryList.add(query);
    }

    return queryList.join(',').replaceAll(RegExp(r',\s?\)'), ')');
  }

  String _mysqlAiToSerial(String str) {
    if (str.contains("AUTO_INCREMENT")) {
      str = str
          .replaceAll("AUTO_INCREMENT", "PRIMARY KEY")
          .replaceAll(
              RegExp(r"BIGINT\((\d+)\)", caseSensitive: false), "BIGSERIAL")
          .replaceAll(
              RegExp(r"(^|\s|,)INT\((\d+)\)", caseSensitive: false), " SERIAL")
          .replaceAll(RegExp(r"(^|\s|,)INTEGER\((\d+)\)", caseSensitive: false),
              " SERIAL")
          .replaceAll(
              RegExp(r"MEDIUMINT\((\d+)\)", caseSensitive: false), "SERIAL")
          .replaceAll(
              RegExp(r"SMALLINT\((\d+)\)", caseSensitive: false), "SMALLSERIAL")
          .replaceAll(
              RegExp(r"TINYINT\((\d+)\)", caseSensitive: false), "SMALLSERIAL");
    }

    if (RegExp(r"PRIMARY KEY \(`.*?`\) USING BTREE").hasMatch(str)) {
      str = str.replaceAll(
          RegExp(r"PRIMARY KEY \(`.*?`\) USING BTREE", caseSensitive: false),
          "");
    }

    if (RegExp(r"PRIMARY KEY \(`.*?`\)").hasMatch(str)) {
      str = str.replaceAll(
          RegExp(r"PRIMARY KEY \(`.*?`\)", caseSensitive: false), "");
    }

    if (RegExp(r"UNSIGNED").hasMatch(str)) {
      str = str.replaceAll(RegExp(r"UNSIGNED", caseSensitive: false), "");
    }

    return str;
  }
}
