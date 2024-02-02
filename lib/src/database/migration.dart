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
    String? constraint,
    String onUpdate = 'NO ACTION',
    String onDelete = 'NO ACTION',
  }) {
    constraint ??= 'FK_${tableName}_$referencesTable';

    final fk =
        'CONSTRAINT `$constraint` FOREIGN KEY (`$columnName`) REFERENCES `$referencesTable` (`$referencesColumn`) ON UPDATE $onUpdate ON DELETE $onDelete';
    foreignKey.add(fk);
  }
}
