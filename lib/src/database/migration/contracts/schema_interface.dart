import '../../../enum/column_index.dart';

abstract class SchemaInterface {
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
  });

  void primary(String columnName, [String algorithm = 'BTREE']);

  void index(ColumnIndex type, String name, List<String> columns);

  void foreign(
    String columnName,
    String referencesTable,
    String referencesColumn, {
    bool constrained = true,
    String onUpdate = 'CASCADE',
    String onDelete = 'CASCADE',
  });

  List<String> get queries;

  List<String> get foreignKeys;

  List<String> get indexes;

  String get primaryField;

  String get primaryAlgorithm;

  void reset();
}
