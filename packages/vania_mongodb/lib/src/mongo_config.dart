class MongoConfig {
  const MongoConfig({required this.uri, this.database});

  final String uri;
  final String? database;

  factory MongoConfig.fromMap(Map<String, dynamic> config) {
    final uri = config['uri'] ?? config['url'];
    if (uri is String && uri.isNotEmpty) {
      return MongoConfig(uri: uri, database: config['database']);
    }

    final host = config['host'] ?? 'localhost';
    final port = config['port'] ?? 27017;
    final database = config['database'] ?? '';
    final username = config['username'];
    final password = config['password'];
    final credentials = username != null && username.toString().isNotEmpty
        ? '${Uri.encodeComponent(username.toString())}:'
              '${Uri.encodeComponent((password ?? '').toString())}@'
        : '';

    return MongoConfig(
      uri: 'mongodb://$credentials$host:$port/$database',
      database: database,
    );
  }
}
