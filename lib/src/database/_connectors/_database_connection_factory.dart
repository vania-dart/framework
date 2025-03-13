import '../../exception/invalid_argument_exception.dart';
import '../_database_utils/_db_config.dart';
import '../../contract/database/_connectors/_database_connection.dart';
import '../adapters/_mysql_connector.dart';
import '../adapters/_postgres_connector.dart';
import '../adapters/_sqlite_connector.dart';

class DatabaseConnectionFactory {
  static DatabaseConnection createConnection(DBConfig config) {
    return switch (config.driver) {
      'mysql' => MySqlConnector(config),
      'pgsql' => PostgresConnector(config),
      'sqlite' => SQLiteConnector(config),
      _ => throw InvalidArgumentException(
          "Unsupported driver [${config.driver}].",
        ),
    };
  }
}
