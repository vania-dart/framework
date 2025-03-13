import 'dart:io';

import 'package:meta/meta.dart';
import 'package:vania/vania.dart';
import '../contract/database/_connectors/_database_connection.dart';
import '../exception/invalid_argument_exception.dart';
import '../database/_database_utils/_db_config.dart';
import '_connection_manager.dart';

class MigrationConnection {
  static final MigrationConnection _singleton = MigrationConnection._internal();

  DatabaseConnection? dbConnection;
  String? driver;

  factory MigrationConnection() => _singleton;

  MigrationConnection._internal();

  Future<void> setup(Map<String, dynamic> databaseConfig) async {
    try {
      final connectionManager = ConnectionManager();

      final Map<String, dynamic> database = databaseConfig['database'];

      connectionManager.defaultConnection = database['default'];

      Map<String, dynamic> connections = database['connections'];

      final defaultConnName = database['default'];
      await connectionManager.connect(
        _createDBConfig(connections[defaultConnName]),
        defaultConnName,
      );

      driver = connections[defaultConnName]['driver'];

      dbConnection = connectionManager.connection(defaultConnName);

      if (dbConnection == null) {
        stderr.writeln('A database must be specified.');
        exit(0);
      }
    } on InvalidArgumentException catch (e) {
      stderr.writeln('Database connection error');
      Logger.log(e.message, type: Logger.ERROR);
      exit(0);
    } catch (e) {
      Logger.log(e.toString(), type: Logger.ERROR);
      stderr.writeln(e);
      exit(0);
    }
  }

  DBConfig _createDBConfig(Map<String, dynamic> config) {
    return DBConfig(
      driver: config['driver'] ?? '',
      host: config['host'] ?? '',
      port: config['port'] ?? 0,
      database: config['database'] ?? '',
      username: config['username'] ?? '',
      password: config['password'] ?? '',
      sslMode: config['sslmode'] ?? false,
      collation: config['collation'] ?? '',
      pool: config['pool'] ?? false,
      poolSize: config['poolsize'] ?? 0,
      filePath: config['file_path'] ?? '',
      openInMemorySQLite: config['openInMemorySQLite'] ?? '',
    );
  }

  Future<void> closeConnection() async {
    await dbConnection?.close();
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
      stderr.writeln('A database must be specified.');
      exit(0);
    }
  }

  @mustBeOverridden
  @mustCallSuper
  Future<void> down() async {
    if (MigrationConnection().dbConnection == null) {
      stderr.writeln('A database must be specified.');
      exit(0);
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

      // Check for PostgreSQL driver - handle case-insensitive comparison
      final driverName = MigrationConnection().driver?.toLowerCase() ?? '';
      if (driverName == 'pgsql') {
        sqlQuery = _mysqlToPosgresqlMapper(sqlQuery);
      }

      await MigrationConnection()
          .dbConnection
          ?.execute(sqlQuery.replaceAll(RegExp(r',\s?\)'), ')'), {});

      stopwatch.stop();
      stderr.writeln(
          ' Create $name table....................................\x1B[32m ${stopwatch.elapsedMilliseconds}ms DONE\x1B[0m');
    } catch (e) {
      stderr.writeln(e);
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
      // Check for PostgreSQL driver - handle case-insensitive comparison
      final driverName = MigrationConnection().driver?.toLowerCase() ?? '';
      if (driverName == 'pgsql') {
        sqlQuery = _mysqlToPosgresqlMapper(sqlQuery);
      }
      await MigrationConnection()
          .dbConnection
          ?.execute(sqlQuery.replaceAll(RegExp(r',\s?\)'), ')'), {});

      stopwatch.stop();
      stderr.writeln(
          ' Create $name table....................................\x1B[32m ${stopwatch.elapsedMilliseconds}ms DONE\x1B[0m');
    } catch (e) {
      stderr.writeln(e);
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

      // Check for PostgreSQL driver - handle case-insensitive comparison
      final driverName = MigrationConnection().driver?.toLowerCase() ?? '';
      if (driverName == 'pgsql') {
        query = _mysqlToPosgresqlMapper(query.toString());
      }

      await MigrationConnection().dbConnection?.execute(query, {});
      stderr
          .writeln('ALTER column to $_tableName table... \x1B[32mDONE\x1B[0m');
    } catch (e) {
      if (!e.toString().contains("write; duplicate key in table")) {
        stderr.writeln('Error adding column: $e');
        exit(0);
      }
    }
  }

  Future<void> dropIfExists(String name) async {
    try {
      String query = 'DROP TABLE IF EXISTS `$name`;';

      // Check for PostgreSQL driver - handle case-insensitive comparison
      final driverName = MigrationConnection().driver?.toLowerCase() ?? '';
      if (driverName == 'pgsql') {
        query = _mysqlToPosgresqlMapper(query.toString());
      } else {
        query =
            'SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;${query}SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;';
      }

      await MigrationConnection().dbConnection?.execute(query.toString(), {});

      stderr.writeln(
          ' Dropping $name table....................................\x1B[32mDONE\x1B[0m');
    } catch (e) {
      stderr.writeln(e);
      exit(0);
    }
  }

  Future<void> drop(String name) async {
    String query = 'DROP TABLE `$name`;';

    // Check for PostgreSQL driver - handle case-insensitive comparison
    final driverName = MigrationConnection().driver?.toLowerCase() ?? '';
    if (driverName == 'pgsql') {
      query = _mysqlToPosgresqlMapper(query.toString());
    } else {
      query =
          'SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;${query}SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;';
    }

    await MigrationConnection().dbConnection?.execute(query.toString(), {});
    stderr.writeln(
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
    bool unique = false,
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

    if (unique) {
      columnDefinition.write(' UNIQUE');
    }

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
    // Check for PostgreSQL driver - handle case-insensitive comparison
    final driverName = MigrationConnection().driver?.toLowerCase() ?? '';
    if (driverName == 'postgresql' ||
        driverName == 'postgres' ||
        driverName == 'pgsql') {
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
    int length = 36,
    String? comment,
    String? collation,
    String? expression,
    String? virtuality,
    bool unique = false,
  }) {
    char(
      name,
      nullable: nullable,
      length: length,
      comment: comment,
      collation: collation,
      expression: expression,
      virtuality: virtuality,
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
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
    bool unique = false,
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
      unique: unique,
    );
  }

  /// Mapper for mysql to postgresql query
  String _mysqlToPosgresqlMapper(String queryStr) {
    queryStr = queryStr.replaceAllMapped(
        RegExp(
            r'`(\w+)`\s+BIGINT\(\d+\)\s+UNSIGNED\s+NOT\s+NULL\s+AUTO_INCREMENT',
            caseSensitive: false),
        (match) => '"${match[1]}" SERIAL NOT NULL PRIMARY KEY');

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
