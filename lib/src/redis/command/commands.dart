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

  /// GET command (get value)
  Future<V?> get(K key);

  /// SET command (set value)
  Future<bool> set(K key, V value);

  /// GETDEL command (get value and delete value)
  Future<V?> getdel(K key);
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
