class DBConfig {
  final String driver;
  final String host;
  final int port;
  final String username;
  final String password;
  final String database;
  final String collation;
  final bool sslMode;
  final bool openInMemorySqlit;
  final String? filePath;
  final bool? pool;
  final int? poolSize;

  DBConfig({
    required this.driver,
    this.host = '',
    this.port = 0,
    this.username = '',
    this.password = '',
    this.database = '',
    this.filePath,
    this.sslMode = false,
    this.openInMemorySqlit = false,
    this.collation = 'utf8mb4_general_ci',
    this.pool = false,
    this.poolSize = 0,
  });
}
