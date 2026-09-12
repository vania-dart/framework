import '../blueprint/table_blueprint.dart';

abstract class DatabaseAdapterInterface {
  String get driverName;

  /// Name of the table/collection the migration history is recorded in.
  /// Must match whatever [getMigrationsTableSql] creates.
  String get migrationsTable => 'migrations';

  String adaptQuery(String query);

  String getMigrationsTableSql();

  bool supports(String driver);

  String escapeIdentifier(String identifier);

  String formatValue(dynamic value);

  List<String> renderCreateTable(
    TableBlueprint blueprint, {
    bool ifNotExists = false,
  });

  List<String> renderAlterAddColumns(
    String table,
    TableBlueprint changes, {
    String afterColumn = '',
    String beforeColumn = '',
  });

  /// Renders table-level options set through [TableDefinition] (engine,
  /// charset, collation, comment, auto-increment seed). Most of these are
  /// MySQL-only; adapters return an empty list for options their engine has
  /// no equivalent for, so a migration stays portable across drivers.
  List<String> renderTableOptions(
    String tableName, {
    String? engine,
    String? charset,
    String? collation,
    String? comment,
    int? autoIncrement,
  });

  List<String> renderDropTable(String tableName, {bool ifExists = false});

  List<String> renderDropColumn(String tableName, String columnName);

  List<String> renderRenameColumn(
    String tableName,
    String oldName,
    String newName,
  );

  List<String> renderRenameTable(String oldName, String newName);

  List<String> renderAddIndex(String tableName, IndexBlueprint index);

  List<String> renderDropIndex(String tableName, String indexName);
}
