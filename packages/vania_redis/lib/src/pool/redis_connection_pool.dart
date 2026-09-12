import 'dart:async';
import 'dart:collection';

import '../command/client.dart';
import '../config.dart';

class RedisConnectionPool {
  RedisConnectionPool(this.config);

  final RedisConfig config;
  final Queue<RedisClient> _available = Queue<RedisClient>();
  final Queue<Completer<RedisClient>> _waiters =
      Queue<Completer<RedisClient>>();
  int _created = 0;

  Future<T> execute<T>(Future<T> Function(RedisClient client) action) async {
    final client = await acquire();
    try {
      return await action(client);
    } finally {
      release(client);
    }
  }

  Future<RedisClient> acquire() async {
    if (_available.isNotEmpty) return _available.removeFirst();
    if (_created < config.poolSize) {
      _created++;
      try {
        return await RedisClient.connectWithConfig(config);
      } catch (_) {
        _created--;
        rethrow;
      }
    }
    final completer = Completer<RedisClient>();
    _waiters.addLast(completer);
    return completer.future;
  }

  void release(RedisClient client) {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(client);
      return;
    }
    _available.addLast(client);
  }

  Future<void> close() async {
    while (_available.isNotEmpty) {
      await _available.removeFirst().close();
      _created--;
    }
  }
}
