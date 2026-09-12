import 'package:vania_redis/vania_redis.dart';
import 'package:redis_cache/store/counter_store.dart';

/// Redis-backed [CounterStore]. `Redis().command` is the string command
/// client; `INCR`/`GET`/`DEL` map straight onto it.
class RedisCounterStore implements CounterStore {
  String _key(String key) => 'views:$key';

  @override
  Future<int> increment(String key) async =>
      await Redis().command.incr(_key(key)) ?? 0;

  @override
  Future<int> current(String key) async {
    final value = await Redis().command.get(_key(key));
    return int.tryParse(value ?? '0') ?? 0;
  }

  @override
  Future<void> reset(String key) async {
    await Redis().command.del(_key(key));
  }
}
