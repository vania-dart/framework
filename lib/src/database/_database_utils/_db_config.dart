class DBConfig {
  final String driver;
  final String host;
  final int port;
  final String username;
  final String password;
  final String database;
  final String collation;
  final bool sslMode;
  final bool openInMemorySQLite;
  final String? filePath;
  final String? schema;
  String? timezone;
  final bool pool;
  int poolSize;

  DBConfig({
    required this.driver,
    this.host = 'mysql',
    this.port = 3306,
    this.username = 'root',
    this.password = '',
    this.database = 'vania',
    this.timezone,
    this.filePath,
    this.sslMode = false,
    this.openInMemorySQLite = false,
    this.collation = 'utf8mb4_general_ci',
    this.schema,
    this.pool = false,
    this.poolSize = 2,
  });
}
