import 'package:vania/foundation.dart' show InvalidArgumentException;

import '../config/db_config.dart';
import '../contract/database_connection.dart';

typedef DatabaseConnectionBuilder =
    DatabaseConnection Function(DBConfig config);

/// The single, process-global driver registry.
class DatabaseConnectionFactory {
  static final Map<String, DatabaseConnectionBuilder> _builders = {};

  static void register(
    String driver,
    DatabaseConnectionBuilder builder, {
    List<String> aliases = const [],
  }) {
    _builders[_normalize(driver)] = builder;
    for (final alias in aliases) {
      _builders[_normalize(alias)] = builder;
    }
  }

  static bool isRegistered(String driver) {
    return _builders.containsKey(_normalize(driver));
  }

  static DatabaseConnection createConnection(DBConfig config) {
    final driver = _normalize(config.driver);
    final builder = _builders[driver];

    if (builder == null) {
      throw InvalidArgumentException(
        "Unsupported driver [${config.driver}]. "
        "Install and register the matching Vania database driver package.",
      );
    }

    return builder(config);
  }

  static void debugClear() => _builders.clear();

  static String _normalize(String driver) => driver.toLowerCase().trim();
}
