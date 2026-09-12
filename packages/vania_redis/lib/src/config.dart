import 'package:vania/foundation.dart' show env;

/// Runtime configuration for Redis.
class RedisConfig {
  const RedisConfig({
    required this.host,
    required this.port,
    this.database = 0,
    this.username,
    this.password,
    this.prefix = '',
    this.secure = false,
    this.poolSize = 2,
    this.scriptsPath,
    this.warmUp = false,
  });

  final String host;
  final int port;
  final int database;
  final String? username;
  final String? password;
  final String prefix;
  final bool secure;
  final int poolSize;

  /// Filesystem path containing `.lua` scripts to preload at boot.
  /// When `null` no directory scan happens. Programmatically-registered
  /// scripts via [RedisScriptRepository.register] are unaffected.
  final String? scriptsPath;

  /// When `true`, [RedisServiceProvider.boot] eagerly opens the connection
  /// and preloads Lua scripts. When `false` (default), everything is lazy.
  final bool warmUp;

  factory RedisConfig.fromEnv() {
    return RedisConfig(
      host: env<String>('REDIS_HOST', '127.0.0.1'),
      port: env<int>('REDIS_PORT', 6379),
      database: env<int>('REDIS_DB', 0),
      username: env<String?>('REDIS_USERNAME'),
      password: env<String?>('REDIS_PASSWORD'),
      prefix: env<String>('REDIS_PREFIX', ''),
      secure: env<bool>('REDIS_TLS', false),
      poolSize: env<int>('REDIS_POOL_SIZE', 2),
      scriptsPath: env<String?>('REDIS_SCRIPTS_PATH'),
      warmUp: env<bool>('REDIS_WARM_UP', false),
    );
  }

  factory RedisConfig.fromMap(Map<String, dynamic> config) {
    return RedisConfig(
      host: config['host']?.toString() ?? '127.0.0.1',
      port: int.tryParse('${config['port'] ?? 6379}') ?? 6379,
      database: int.tryParse('${config['database'] ?? config['db'] ?? 0}') ?? 0,
      username: config['username']?.toString(),
      password: config['password']?.toString(),
      prefix: config['prefix']?.toString() ?? '',
      secure: config['secure'] == true || config['tls'] == true,
      poolSize: int.tryParse('${config['pool_size'] ?? 2}') ?? 2,
      scriptsPath: (config['scripts_path'] ?? config['scriptsPath'])
          ?.toString(),
      warmUp: config['warm_up'] == true || config['warmUp'] == true,
    );
  }
}
