abstract class KeysCommands<K, V> {
  Future<bool> del(K key);
  Future<int> delMany(List<K> keys);
  Future<bool> exists(K key);
  Future<int> existsMany(List<K> keys);
  Future<bool> expire(K key, Duration duration);
  Future<bool> persist(K key);
  Future<List<String>> keys(String pattern);
  Future<RedisScanResult> scan({
    int cursor = 0,
    String? match,
    int? count,
    String? type,
  });
  Future<int?> ttl(K key);
  Future<int?> pttl(K key);
  Future<V?> get(K key);
  Future<bool> set(K key, V value);
  Future<bool> setEx(K key, int ttl, V value);
  Future<bool> pSetEx(K key, int ttl, V value);
  Future<bool> setNx(K key, V value);
  Future<V?> getdel(K key);
  Future<V?> getSet(K key, V value);
  Future<int?> append(K key, V value);
  Future<int?> bitCount(K key, {int? start, int? end});
  Future<int?> bitOp(String operation, K destKey, List<K> keys);
  Future<int?> bitPos(K key, int bit, {int? start, int? end});
  Future<int?> decr(K key);
  Future<int?> decrBy(K key, int decrement);
  Future<int?> getBit(K key, int offset);
  Future<V?> getRange(K key, int start, int end);
  Future<int?> incr(K key);
  Future<int?> incrBy(K key, int increment);
  Future<double?> incrByFloat(K key, double increment);
  Future<List<V?>> mGet(List<K> keys);
  Future<bool> mSet(Map<K, V> keyValues);
  Future<bool> mSetNX(Map<K, V> keyValues);
  Future<int?> setBit(K key, int offset, int value);
  Future<int?> setRange(K key, int offset, V value);
  Future<int?> strlen(K key);
  Future<bool> setOption(String option, String value);
  Future<String?> getOption(String option);
}

abstract class HashCommands<K, V> {
  Future<int?> hSet(K key, String field, V value);
  Future<V?> hGet(K key, String field);
  Future<int?> hDel(K key, List<String> fields);
  Future<bool> hExists(K key, String field);
  Future<Map<String, V>> hGetAll(K key);
  Future<List<String>> hKeys(K key);
  Future<List<V>> hVals(K key);
  Future<int?> hLen(K key);
}

abstract class ListCommands<K, V> {
  Future<List<V>> lrange(K key, int startIndex, int endIndex);
  Future<int?> rpush(K key, List<V> values);
  Future<int?> lpush(K key, List<V> values);
  Future<bool> lset(K key, int index, V value);
  Future<V?> lpop(K key);
  Future<V?> rpop(K key);
  Future<int?> llen(K key);
}

abstract class SetCommands<K, V> {
  Future<int?> sAdd(K key, List<V> members);
  Future<int?> sRem(K key, List<V> members);
  Future<bool> sIsMember(K key, V member);
  Future<List<V>> sMembers(K key);
}

abstract class SortedSetCommands<K, V> {
  Future<int?> zAdd(K key, Map<V, num> scores);
  Future<List<V>> zRange(K key, int start, int stop);
  Future<int?> zRem(K key, List<V> members);
  Future<double?> zScore(K key, V member);
}

abstract class TransactionCommands<K, V> {
  Future<void> multi();
  Future<void> exec();
  Future<void> discard();
  Future<List<dynamic>> transaction(
    Future<void> Function(RedisTransaction tx) action,
  );
}

abstract class PubSubCommands<V> {
  Future<int?> publish(String channel, V message);
}

abstract class ScriptCommands {
  Future<dynamic> eval(
    String script, {
    List<String> keys = const [],
    List<dynamic> arguments = const [],
  });
  Future<dynamic> evalSha(
    String sha, {
    List<String> keys = const [],
    List<dynamic> arguments = const [],
  });
  Future<String> scriptLoad(String script);
  Future<List<bool>> scriptExists(List<String> sha1);
  Future<String?> scriptFlush();
}

abstract class RawRedisCommands {
  Future<dynamic> raw(List<dynamic> command);
  Future<List<dynamic>> pipeline(List<List<dynamic>> commands);
}

abstract class Commands<K, V>
    implements
        KeysCommands<K, V>,
        HashCommands<K, V>,
        ListCommands<K, V>,
        SetCommands<K, V>,
        SortedSetCommands<K, V>,
        TransactionCommands<K, V>,
        PubSubCommands<V>,
        ScriptCommands,
        RawRedisCommands {}

class RedisScanResult {
  const RedisScanResult({required this.cursor, required this.keys});

  final int cursor;
  final List<String> keys;

  bool get isComplete => cursor == 0;
}

class RedisTransaction {
  RedisTransaction(this._send);

  final Future<dynamic> Function(List<dynamic> command) _send;

  Future<dynamic> raw(List<dynamic> command) => _send(command);
}
