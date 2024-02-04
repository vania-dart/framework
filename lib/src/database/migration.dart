import 'package:meta/meta.dart';
import 'package:vania/src/enum/column_index.dart';

class Migration {
  String tableName = '';
  List<String> queries = [];
  List<String> foreignKey = [];
  String primaryField = '';
  String primaryAlgorithm = '';
  List<String> indexes = [];

  @mustBeOverridden
  void up() {}

  void createTable(String name, Function callback) {
    final query = StringBuffer();
    tableName = name;
    callback();
    String index = indexes.isNotEmpty ? '${indexes.join(',')},\n' : '';
    String foreig = foreignKey.isNotEmpty ? '${foreignKey.join(',')}\n' : '';
    String primary = primaryField.isNotEmpty
        ? 'PRIMARY KEY (`$primaryField`) USING $primaryAlgorithm,\n'
        : '';
    query.write(
        """DROP TABLE IF EXISTS $name; CREATE TABLE `$name` (${queries.join(',\n\t')},\n$primary$index$foreig)""");

    print('Table $name created');
  }

  void createTableNotExists(String name, Function callback) {
    final query = StringBuffer();
    tableName = name;
    callback();
    String index = indexes.isNotEmpty ? '${indexes.join(',')},\n' : '';
    String foreig = foreignKey.isNotEmpty ? '${foreignKey.join(',')}\n' : '';
    String primary = primaryField.isNotEmpty
        ? 'PRIMARY KEY (`$primaryField`) USING $primaryAlgorithm,\n'
        : '';
    query.write(
        """CREATE TABLE IF NOT EXISTS `$name` (${queries.join(',\n\t')},\n$primary$index$foreig)""");

    print('Table $name created');
  }

  void dropTable(String name) {
    String query = 'DROP TABLE IF EXISTS $name;';
    print('Table $name droped');
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
    if (type == ColumnIndex.INDEX) {
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
      length: 1,
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
      'FLOAT',
      nullable: nullable,
      length: '$precision,$scale',
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
      'DOUBLE',
      nullable: nullable,
      length: '$precision,$scale',
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
      'DECIMAL',
      nullable: nullable,
      length: '$precision,$scale',
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
      'TEXT',
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

  void mediumText(
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
      'MEDIUMTEXT',
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

  void longText(
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
      'LONGTEXT',
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

}
