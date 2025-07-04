abstract class DatabaseAdapterInterface {
  String get driverName;

  String adaptQuery(String query);

  String getMigrationsTableSql();

  bool supports(String driver);

  String escapeIdentifier(String identifier);

  String formatValue(dynamic value);
}
