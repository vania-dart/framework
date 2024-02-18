abstract class CacheDriver {
  Future<void> put(String key, String value, {Duration? duration});

  Future<void> forever(String key, String value);

  Future<void> delete(String key);

  Future<String?> get(String key);

  Future<bool> has(String key);
}
