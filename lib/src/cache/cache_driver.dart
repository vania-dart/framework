abstract class CacheDriver {
  Future<void> put(String key, dynamic value, {Duration duration});

  Future<void> forever(String key, dynamic value);

  Future<void> delete(String key);

  Future<dynamic> get(String key, [dynamic defaultValue]);

  Future<bool> has(String key);
}
