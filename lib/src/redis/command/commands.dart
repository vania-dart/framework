/// key-value operation commands
abstract class KeysCommands<K, V> {
  /// DEL command (delete item)
  Future<bool> del(K key);

  /// EXISTS command (check existence)
  Future<bool> exists(K key);

  /// EXPIRE command (set expire duration)
  Future<bool> expire(K key, Duration duration);

  /// KEYS command (get keys that match [pattern])
  Future<List<String>> keys(String pattern);

  /// Returns the remaining time to live of a key  (get value)
  Future<int?> ttl(K key);

  /// GET command (get value)
  Future<V?> get(K key);

  /// SET command (set value)
  Future<bool> set(K key, V value);

  /// SET expire duration command (set value)
  Future<bool> setEx(K key, int ttl, V value);

  /// GETDEL command (get value and delete value)
  Future<V?> getdel(K key);

  Future<int?> append(K key, V value);

  Future<int?> bitCount(K key, {int? start, int? end});

  Future<int?> bitOp(String operation, K destKey, List<K> keys);

  Future<int?> bitPos(K key, int bit, {int? start, int? end});

  Future<int?> decr(K key);

  Future<int?> decrBy(K key, int decrement);

  Future<int?> getBit(K key, int offset);

  Future<V?> getSet(K key, V value);

  Future<int?> incr(K key);

  Future<int?> incrBy(K key, int increment);

  Future<double?> incrByFloat(K key, double increment);

  Future<List<V>> mGet(List<K> keys);

  Future<bool> mSet(Map<K, V> keyValues);

  Future<bool> mSetNX(Map<K, V> keyValues);

  Future<int?> setBit(K key, int offset, int value);

  Future<bool> pSetEx(K key, int ttl, V value);

  Future<bool> setNx(K key, V value);

  Future<int?> setRange(K key, int offset, V value);

  Future<V?> getRange(K key, int start, int end);

  Future<int?> strlen(K key);

  Future<bool> setOption(String option);

  Future<String?> getOption(String option);
}

/// list operation commands
abstract class ListCommands<K, V> {
  /// LRANGE command (get range [startIndex] to [endIndex])
  Future<List<V>> lrange(K key, int startIndex, int endIndex);

  /// RPUSH command (push to right side)
  Future<bool> rpush(K key, List<V> values);

  /// LPUSH command (push to left side)
  Future<bool> lpush(K key, List<V> values);

  /// LSET command (set value that placed in [index])
  Future<bool> lset(K key, int index, V value);
}

/// transaction operation commands
abstract class TransactionCommands<K, V> {
  /// MULTI command (start transaction)
  Future<void> multi();

  /// EXEC command (apply transaction)
  Future<void> exec();

  /// DISCARD command (abort transaction)
  Future<void> discard();
}

/// pubsub operation commands
abstract class PubSubCommands<V> {
  /// PSUBSCRIBE command (pattern subscribe)
  Stream<V> psubscribe(String pattern);

  /// PUBLISH command (publish [message] to [channel])
  Future<int?> publish(String channel, V message);
}
