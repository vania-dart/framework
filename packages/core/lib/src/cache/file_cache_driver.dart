import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/helper.dart';
import 'cache_driver.dart';

class FileCacheDriver implements CacheDriver {
  static final FileCacheDriver _instance = FileCacheDriver._internal();
  factory FileCacheDriver() => _instance;
  FileCacheDriver._internal();

  final String _cacheDir = storagePath('framework/cache');

  @override
  Future<dynamic> get(String key, [dynamic defaultValue]) async {
    final file = _getCacheFile(key);
    if (!await file.exists()) return defaultValue;

    try {
      final data = await file.readAsString();
      final cache = jsonDecode(data);

      if (cache['expiration'] != null) {
        final expiration = DateTime.parse(cache['expiration']);
        if (DateTime.now().isAfter(expiration)) {
          await file.delete();
          return defaultValue;
        }
      }

      return cache['value'] ?? defaultValue;
    } catch (e) {
      await file.delete();
      return defaultValue;
    }
  }

  @override
  Future<void> put(
    String key,
    dynamic value, {
    Duration duration = const Duration(hours: 1),
  }) async {
    final file = _getCacheFile(key);
    await _ensureCacheDirectory();

    final cache = {
      'value': value,
      'expiration': DateTime.now().add(duration).toIso8601String(),
    };
    await file.writeAsString(jsonEncode(cache));
  }

  @override
  Future<void> forever(String key, dynamic value) async {
    if (value == null) {
      throw Exception("Value can't be null");
    }

    final file = _getCacheFile(key);
    await _ensureCacheDirectory();

    final cache = {'value': value, 'expiration': null};

    await file.writeAsString(jsonEncode(cache));
  }

  @override
  Future<bool> has(String key) async {
    final value = await get(key);
    return value != null;
  }

  @override
  Future<bool> delete(String key) async {
    final file = _getCacheFile(key);
    if (!await file.exists()) return false;

    try {
      await file.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  File _getCacheFile(String key) {
    final fileName = base64Url.encode(utf8.encode(key));
    return File(path.join(_cacheDir, fileName));
  }

  Future<void> _ensureCacheDirectory() async {
    final dir = Directory(_cacheDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
}
