import '../../enum/column_index.dart';
import 'column_blueprint.dart';

class IndexBlueprint {
  final String name;
  final List<String> columns;
  final ColumnIndex type;

  const IndexBlueprint({
    required this.name,
    required this.columns,
    this.type = ColumnIndex.indexKey,
  });
}

class ForeignKeyBlueprint {
  final String columnName;
  final String referencesTable;
  final String referencesColumn;
  final String onUpdate;
  final String onDelete;
  final bool constrained;

  const ForeignKeyBlueprint({
    required this.columnName,
    required this.referencesTable,
    required this.referencesColumn,
    this.onUpdate = 'CASCADE',
    this.onDelete = 'CASCADE',
    this.constrained = true,
  });
}

class UniqueConstraintBlueprint {
  final String name;
  final List<String> columns;

  const UniqueConstraintBlueprint({required this.name, required this.columns});
}

class TableBlueprint {
  final String tableName;
  final List<ColumnBlueprint> columns;
  final String? primaryKey;
  final String primaryAlgorithm;
  final List<IndexBlueprint> indexes;
  final List<ForeignKeyBlueprint> foreignKeys;
  final List<UniqueConstraintBlueprint> uniqueConstraints;

  const TableBlueprint({
    required this.tableName,
    this.columns = const [],
    this.primaryKey,
    this.primaryAlgorithm = 'BTREE',
    this.indexes = const [],
    this.foreignKeys = const [],
    this.uniqueConstraints = const [],
  });
}
