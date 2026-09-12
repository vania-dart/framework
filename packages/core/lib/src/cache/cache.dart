import 'package:vania/src/cache/file_cache_driver.dart';
import 'package:vania/src/ioc_container.dart';
import 'package:vania/env.dart' show env;

import 'cache_driver.dart';

class Cache {
  Cache.createDefault();

  factory Cache() =>
      IoCContainer().resolveOrDefault<Cache>(Cache.createDefault);

  final Map<String, CacheDriver Function()> _drivers = {
    'file': FileCacheDriver.new,
  };

  static void registerDriver(String name, CacheDriver Function() factory) {
    Cache()._drivers[name] = factory;
  }

  CacheDriver get _driver {
    final driver = env<String>('CACHE_DRIVER', 'file');
    final factory = _drivers[driver] ?? _drivers['file']!;
    return factory();
  }

  /// set key => value to cache
  /// default duration is 1 hour
  /// ```
  /// await Cache.put('foo', 'bar');
  /// await Cache.put('foo', 'bar', duration: Duration(hours: 24));
  /// ```
  static Future<void> put(
    String key,
    dynamic value, {
    Duration duration = const Duration(hours: 1),
  }) async {
    if (value == null) {
      throw Exception("Value can't be null");
    }
    await Cache()._driver.put(key, value, duration: duration);
  }

  /// set key => value to cache forever
  /// ```
  /// await Cache.forever('foo', 'bar');
  /// ```
  static Future<void> forever(String key, String value) async {
    await Cache()._driver.forever(key, value);
  }

  /// remove a key from cache
  /// ```
  /// await Cache.delete('foo');
  ///
  static Future<void> delete(String key) async {
    await Cache()._driver.delete(key);
  }

  /// get a value from cache
  /// ```
  /// String? value = await Cache.get('foo');
  ///
  static Future<dynamic> get(String key, [dynamic defaultValue]) async {
    return await Cache()._driver.get(key, defaultValue);
  }

  /// get a value exist
  /// ```
  /// bool has = await Cache.has('foo');
  ///
  static Future<bool> has(String key) async {
    return await Cache()._driver.has(key);
  }
}
