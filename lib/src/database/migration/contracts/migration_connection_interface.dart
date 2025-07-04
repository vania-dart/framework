import '../../../contract/database/_connectors/_database_connection.dart';

abstract class MigrationConnectionInterface {
  DatabaseConnection? get connection;

  String? get driver;

  Future<void> setup(Map<String, dynamic> databaseConfig);

  Future<void> closeConnection();

  Future<void> truncateMigration();
}
