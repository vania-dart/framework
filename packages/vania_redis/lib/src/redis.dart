import 'dart:async';

import 'command/client.dart';
import 'command/commands.dart';
import 'config.dart';
import 'pool/redis_connection_pool.dart';
import 'pubsub/redis_pubsub.dart';
import 'script/redis_script_repository.dart';

/// The framework-wide Redis singleton.
///
/// The connection is lazy — the first read of any state that requires it
/// (see [initialized] and [connect]) opens one command connection plus a
/// small pool. Boot-time wiring is done from [RedisServiceProvider], which
/// also loads Lua scripts from disk into [scripts] when configured.
class Redis {
  factory Redis() => _singleton;

  Redis._internal();

  static final Redis _singleton = Redis._internal();

  late Commands<String, String> command;
  late RedisClient client;
  late RedisConnectionPool pool;

  /// Named Lua scripts loaded from disk or registered programmatically.
  /// See [RedisServiceProvider] for boot-time hydration.
  final RedisScriptRepository scripts = RedisScriptRepository();

  Completer<void>? _completer;
  RedisConfig? _config;

  /// The config the singleton is currently using (or last used). `null`
  /// before the first [connect]/[initialized] call.
  RedisConfig? get config => _config;

  Future<void> get initialized {
    _completer ??= Completer<void>();
    if (!_completer!.isCompleted) {
      _initRedis()
          .then(_completer!.complete)
          .catchError(_completer!.completeError);
    }
    return _completer!.future;
  }

  Future<void> connect([RedisConfig? config]) async {
    _completer = Completer<void>();
    await _initRedis(config);
    _completer!.complete();
  }

  Future<void> close() async {
    await client.close();
    await pool.close();
    _completer = null;
  }

  /// Open a dedicated Pub/Sub session on a fresh connection. Callers own
  /// the returned [RedisPubSub] and must call [RedisPubSub.close] when done.
  Future<RedisPubSub<V>> pubsub<V>({
    List<String> channels = const [],
    List<String> patterns = const [],
  }) async {
    await initialized;
    return client.subscribe<V>(channels: channels, patterns: patterns);
  }

  Future<void> _initRedis([RedisConfig? config]) async {
    final resolved = config ?? RedisConfig.fromEnv();
    _config = resolved;
    client = await RedisClient.connectWithConfig(resolved);
    command = client.getCommands<String, String>();
    pool = RedisConnectionPool(resolved);
  }
}
