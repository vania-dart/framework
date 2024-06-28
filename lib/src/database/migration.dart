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

  Future<void> setup() async {
    Env().load();
    try {
      await DatabaseClient().setup();
      database = DatabaseClient().database;
      if (database == null) {
        print('A driver must be specified.');
        exit(0);
      }
      dbConnection = database?.connection;
    } on InvalidArgumentException catch (e) {
      print('Database connection error');
      Logger.log(e.cause.toString(), type: Logger.ERROR);
      exit(0);
    } catch (e) {
      Logger.log(e.toString(), type: Logger.ERROR);
      print(e);
      exit(0);
    }
  }

  Future<void> closeConnection() async {
    await dbConnection?.disconnect();
  }
}

class Migration {
  String _tableName = '';
  final List<String> _queries = [];
  final List<String> _foreignKey = [];
  String _primaryField = '';
  String _primaryAlgorithm = '';
  final List<String> _indexes = [];

  @mustBeOverridden
  @mustCallSuper
  Future<void> up() async {
    if (MigrationConnection().dbConnection == null) {
      print('A driver must be specified.');
      throw 'A driver must be specified.';
    }
  }

  @mustBeOverridden
  @mustCallSuper
  Future<void> down() async {
    if (MigrationConnection().dbConnection == null) {
      print('A driver must be specified.');
      throw 'A driver must be specified.';
    }
  }

  Future<void> createTable(String name, Function callback) async {
    try {
      Stopwatch stopwatch = Stopwatch()..start();
      final query = StringBuffer();
      _tableName = name;
      callback();
      String index = _indexes.isNotEmpty ? ',${_indexes.join(',')}' : '';
      String foreig = _foreignKey.isNotEmpty ? ',${_foreignKey.join(',')}' : '';
      String primary = _primaryField.isNotEmpty
          ? ',PRIMARY KEY (`$_primaryField`) USING $_primaryAlgorithm'
          : '';
      query.write(
          '''DROP TABLE IF EXISTS `$name`; CREATE TABLE `$name` (${_queries.join(',')}$primary$index$foreig)''');

      String sqlQuery = query.toString();
      if (MigrationConnection().database?.driver == 'Postgresql') {
        sqlQuery = _mysqlToPosgresqlMapper(sqlQuery);
      }

      await MigrationConnection()
          .dbConnection
          ?.execute(sqlQuery.replaceAll(RegExp(r',\s?\)'), ')'));

      stopwatch.stop();
      print(
          ' Create $name table....................................\x1B[32m ${stopwatch.elapsedMilliseconds}ms DONE\x1B[0m');
    } catch (e) {
      print(e);
      exit(0);
    }
  }

  Future<void> createTableNotExists(String name, Function callback) async {
    try {
      Stopwatch stopwatch = Stopwatch()..start();
      final query = StringBuffer();
      _tableName = name;
      callback();
      String index = _indexes.isNotEmpty ? ',${_indexes.join(',')}' : '';
      String foreig = _foreignKey.isNotEmpty ? ',${_foreignKey.join(',')}' : '';
      String primary = _primaryField.isNotEmpty
          ? ',PRIMARY KEY (`$_primaryField`) USING $_primaryAlgorithm'
          : '';
      query.write(
          '''CREATE TABLE IF NOT EXISTS `$name` (${_queries.join(',')}$primary$index$foreig)''');

      String sqlQuery = query.toString();
      if (MigrationConnection().database?.driver == 'Postgresql') {
        sqlQuery = _mysqlToPosgresqlMapper(sqlQuery);
      }
      await MigrationConnection()
          .dbConnection
          ?.execute(sqlQuery.replaceAll(RegExp(r',\s?\)'), ')'));

      stopwatch.stop();
      print(
          ' Create $name table....................................\x1B[32m ${stopwatch.elapsedMilliseconds}ms DONE\x1B[0m');
    } catch (e) {
      print(e);
      exit(0);
    }
  }

  Future<void> alterColumn(
    String table,
    Function callback, {
    String beforeColumn = '',
    String afterColumn = '',
  }) async {
    _tableName = table;
    callback();

    String index = _indexes.isNotEmpty ? ',ADD ${_indexes.join(',')}' : '';
    String foreig =
        _foreignKey.isNotEmpty ? ',ADD ${_foreignKey.join(',')}' : '';

    String alterQuery = '';
    if (_queries.isNotEmpty) {
      alterQuery = 'ADD COLUMN ${_queries.first}';
      if (beforeColumn.isNotEmpty) {
        alterQuery = ' $alterQuery BEFORE `$beforeColumn`';
      } else if (afterColumn.isNotEmpty) {
        alterQuery = ' $alterQuery AFTER `$afterColumn`';
      }
    }

    if (_queries.isEmpty && index.isNotEmpty) {
      index = index.replaceFirst(',', '');
    }

    if (_queries.isEmpty && index.isEmpty) {
      foreig = foreig.replaceFirst(',', '');
    }

    try {
      String query = 'ALTER TABLE `$table` $alterQuery$index$foreig;';

      if (MigrationConnection().database?.driver == 'Postgresql') {
        query = _mysqlToPosgresqlMapper(query.toString());
      }

      await MigrationConnection().dbConnection?.execute(query);
      print('ALTER column to $_tableName table... \x1B[32mDONE\x1B[0m');
    } catch (e) {
      if (!e.toString().contains("write; duplicate key in table")) {
        print('Error adding column: $e');
        exit(0);
      }
    }
  }

  Future<void> dropIfExists(String name) async {
    try {
      String query = 'DROP TABLE IF EXISTS `$name`;';

      if (MigrationConnection().database?.driver == 'Postgresql') {
        query = _mysqlToPosgresqlMapper(query.toString());
      } else {
        query =
            'SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;${query}SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;';
      }

      await MigrationConnection().dbConnection?.execute(query.toString());

      print(
          ' Dropping $name table....................................\x1B[32mDONE\x1B[0m');
    } catch (e) {
      print(e);
      exit(0);
    }
  }

  Future<void> drop(String name) async {
    String query = 'DROP TABLE `$name`;';

    if (MigrationConnection().database?.driver == 'Postgresql') {
      query = _mysqlToPosgresqlMapper(query.toString());
    } else {
      query =
          'SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;${query}SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;';
    }

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
    dynamic defaultValue,
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
      RegExp funcRegex = RegExp(r'^\w+\(.*\)$');
      if (funcRegex.hasMatch(defaultValue.toString())) {
        columnDefinition.write(" DEFAULT $defaultValue");
      } else {
        if (defaultValue is int) {
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

    _queries.add(columnDefinition.toString());
  }

  void primary(String columnName, [String algorithm = 'BTREE']) {
    _primaryField = columnName;
    _primaryAlgorithm = algorithm;
  }

  void index(ColumnIndex type, String name, List<String> columns) {
    if (MigrationConnection().database?.driver == 'pgsql') {
      _indexes.add('INDEX `$name` (${columns.join(',')})');
    } else {
      if (type == ColumnIndex.indexKey) {
        _indexes.add('INDEX `$name` (${columns.map((e) => "`$e`").join(',')})');
      } else {
        _indexes.add(
            '${type.name} INDEX `$name` (${columns.map((e) => "`$e`").join(',')})');
      }
    }
  }

  void foreign(
    String columnName,
    String referencesTable,
    String referencesColumn, {
    bool constrained = true,
    String onUpdate = 'NO ACTION',
    String onDelete = 'NO ACTION',
  }) {
    String constraint = '';
    if (constrained) {
      constraint = 'CONSTRAINT FK_${_tableName}_$referencesTable';
    }

    final fk =
        '$constraint FOREIGN KEY (`$columnName`) REFERENCES `$referencesTable` (`$referencesColumn`) ON UPDATE $onUpdate ON DELETE $onDelete';
    _foreignKey.add(fk);
  }

  void id() {
    bigIncrements('id');
    primary('id');
  }

  void bigIncrements(
    String name, {
    bool nullable = false,
    bool zeroFill = false,
    int? defaultValue,
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
    int? defaultValue,
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
    int? defaultValue,
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
    int? defaultValue,
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
    int? defaultValue,
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
    int? defaultValue,
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
    int? defaultValue,
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

  void timeStamps() {
    timeStamp("created_at", nullable: true);
    timeStamp("updated_at", nullable: true);
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
    if (queryStr.contains("AUTO_INCREMENT")) {
      queryStr = queryStr.replaceAll("AUTO_INCREMENT", "PRIMARY KEY");
    }

    if (RegExp(r"PRIMARY KEY \(`.*?`\) USING BTREE").hasMatch(queryStr)) {
      queryStr = queryStr.replaceAll(
          RegExp(r"PRIMARY KEY \(`.*?`\) USING BTREE", caseSensitive: false),
          "");
    }

    if (RegExp(r"PRIMARY KEY \(`.*?`\)").hasMatch(queryStr)) {
      queryStr = queryStr.replaceAll(
          RegExp(r"PRIMARY KEY \(`.*?`\)", caseSensitive: false), "");
    }

    String query = queryStr
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
        .replaceAll(RegExp(r"LONGTEXT\((\d+)\)", caseSensitive: false), "TEXT")
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
            RegExp(r"DEFAULT\s+(CURRENT_TIMESTAMP\(\))", caseSensitive: false),
            "")
        .replaceAll('`', '"')
        .replaceAll('UNSIGNED', '')
        .replaceAll(',,', ',');

    return query.replaceAll(RegExp(r',\s?\)'), ')');
  }
}
