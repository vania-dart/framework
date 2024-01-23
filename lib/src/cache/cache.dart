import 'package:vania/src/cache/local_cache_driver.dart';
import 'package:vania/vania.dart';

class Cache {
  String? _store;

  Map<String, CacheDriver> cacheDrivers = <String, CacheDriver>{
    'file': LocalCacheDriver(),
    ...Config().get("cache")?.drivers
  };

  /// Set where to store the cache.
  /// The name you set in the cache drivers configuration
  /// Example `drivers => {'file' : LocalCacheDriver()}`,
  /// then store name is `local`
  Cache store(String store) {
    _store = store;
    return this;
  }

  CacheDriver get _driver {
    return cacheDrivers[_store] ??
        cacheDrivers[Config().get("cache")?.defaultDriver] ??
        LocalCacheDriver();
  }

  /// set key => value to cache
  /// default duration is 1 hour
  /// ```
  /// await Cache().put('foo', 'bar');
  /// await Cache().put('foo', 'bar', duration: Duration(hours: 24));
  /// ```
  Future<void> put(String key, String value, {Duration? duration}) async {
     await _driver.put(key, value, duration: duration);
  }

  /// set key => value to cache forever
  /// ```
  /// await Cache().forever('foo', 'bar');
  /// ```
  Future<void> forever(String key, String value) async {
    await _driver.forever(key, value);
  }

  /// remove a key from cache
  /// ```
  /// await Cache().delete('foo');
  ///
  Future<void> delete(String key) async {
    await _driver.delete(key);
  }

  /// get a value from cache
  /// ```
  /// String? value = await Cache().get('foo');
  ///
  Future<dynamic> get(String key) async {
    return await _driver.get(key);
  }

  /// get a value exist
  /// ```
  /// bool has = await Cache().has('foo');
  ///
  Future<bool> has(String key) async {
    return await _driver.has(key);
  }
}
