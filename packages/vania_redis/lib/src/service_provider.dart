import 'package:vania/foundation.dart' show Cache, Config, Logger;
import 'package:vania/service_provider.dart';

import 'cache/redis_cache_driver.dart';
import 'config.dart';
import 'redis.dart';

/// Wires Redis into a Vania application.
///
/// `register()` registers the `redis` cache driver so that
/// `Cache.driver('redis')` resolves to [RedisCacheDriver] without any
/// further boot-time work.
///
/// `boot()` optionally opens the connection eagerly and loads Lua scripts
/// from disk. Both are gated on config so a default install stays lazy —
/// the connection is only opened when app code first calls `Redis()`.
class RedisServiceProvider extends ServiceProvider {
  RedisServiceProvider({this.config});

  /// Explicit config override. When `null`, config is read at boot time
  /// from `Config().get('redis')` (if present) with a fallback to env.
  final RedisConfig? config;

  @override
  Future<void> register() async {
    Cache.registerDriver('redis', RedisCacheDriver.new);
  }

  @override
  Future<void> boot() async {
    final resolved = config ?? _configFromApplication();

    if (resolved.warmUp) {
      try {
        await Redis().connect(resolved);
      } catch (e) {
        Logger.log('vania_redis: warm-up connect failed: $e');
        return;
      }
    }

    final scriptsPath = resolved.scriptsPath;
    if (scriptsPath == null || scriptsPath.isEmpty) return;

    final added = await Redis().scripts.loadDirectory(scriptsPath);
    if (added.isEmpty) return;

    if (resolved.warmUp) {
      try {
        await Redis().scripts.preloadAll(Redis().command);
      } catch (e) {
        Logger.log('vania_redis: Lua SCRIPT LOAD failed: $e');
      }
    }
  }

  RedisConfig _configFromApplication() {
    try {
      final raw = Config().get('redis');
      if (raw is Map<String, dynamic>) return RedisConfig.fromMap(raw);
      if (raw is Map) {
        return RedisConfig.fromMap(Map<String, dynamic>.from(raw));
      }
    } catch (_) {
      // Config not initialised yet in tests — fall through to env.
    }
    return RedisConfig.fromEnv();
  }
}
