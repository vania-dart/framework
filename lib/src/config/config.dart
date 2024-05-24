import 'package:vania/vania.dart';

class Config {
  static final Config _singleton = Config._internal();
  factory Config() => _singleton;
  Config._internal();

  Map<String, dynamic> _config = {};
  set setApplicationConfig(Map<String, dynamic> conf) => _config = conf;

  dynamic get(String key) => _config[key];
}

class FileStorageConfig {
  final String defaultDriver;
  final Map<String, StorageDriver> drivers;

  const FileStorageConfig({
    this.defaultDriver = 'local',
    this.drivers = const <String, StorageDriver>{},
  });
}

class CORSConfig {
  final bool enabled;
  final dynamic origin;
  final dynamic methods;
  final dynamic headers;
  final dynamic exposeHeaders;
  final bool? credentials;
  final num? maxAge;

  const CORSConfig({
    this.enabled = true,
    this.origin,
    this.methods,
    this.headers,
    this.exposeHeaders,
    this.credentials,
    this.maxAge,
  });
}

class DatabaseConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final String database;
  final bool? sslmode;
  final DatabaseDriver? driver;
  final List<String>? schema;
  final bool pool;
  final int poolsize;

  const DatabaseConfig({
    required this.driver,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.database = 'db',
    this.sslmode = true,
    this.schema,
    this.pool = false,
    this.poolsize = 4,
  });
}
