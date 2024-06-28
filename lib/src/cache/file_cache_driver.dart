import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:vania/src/extensions/string_extension.dart';
import 'package:vania/vania.dart';

class FileCacheDriver implements CacheDriver {
  final String _secretKey = env('APP_KEY');

  final String cachePath = 'storage/framework/cache/data';

  @override
  Future<void> delete(String key) async {
    File? file = await _cacheFile(key);
    file?.deleteSync();
  }

  @override
  Future<dynamic> get(String key, [dynamic defaultValue]) async {
    Map<String, dynamic>? data = await _getData(key);

    if (data?['expiration'] != null) {
      int expiration = data?['expiration'].toString().toInt() ?? 0;
      if (!DateTime.now()
          .toUtc()
          .isBefore(DateTime.fromMillisecondsSinceEpoch(expiration))) {
        return Future.value(null);
      }
    }

    if (data?['data'] == null && defaultValue != null) {
      return Future.value(defaultValue);
    }

    return Future.value(data?['data']);
  }

  @override
  Future<bool> has(String key) async {
    dynamic data = await get(key);

    if (data == null) {
      return Future.value(false);
    }

    return Future.value(true);
  }

  @override
  Future<void> put(
    String key,
    dynamic value, {
    Duration duration = const Duration(hours: 1),
  }) async {
    int expiration =
        DateTime.now().toUtc().millisecondsSinceEpoch + duration.inMilliseconds;
    Map<String, dynamic> data = {'data': value, 'expiration': expiration};
    _writeData(key, json.encode(data));
  }

  @override
  Future<void> forever(
    String key,
    dynamic value,
  ) async {
    if (value == null) {
      throw Exception("Value can't be null");
    }
    Map<String, dynamic> data = {'data': value};
    _writeData(key, json.encode(data));
  }

  Future<void> _writeData(String key, String data) async {
    File? file = await _cacheFile(key, true);
    file?.writeAsStringSync(data);
  }

  Future<Map<String, dynamic>?> _getData(String key) async {
    File? file = await _cacheFile(key);
    return Future.value(
        file == null ? null : json.decode(file.readAsStringSync()));
  }

  Future<File?> _cacheFile(String key, [bool create = false]) async {
    Digest hash = _makeHash(key);
    String path =
        '$cachePath/${twoDigest(hash.bytes[0].toString())}/${twoDigest(hash.bytes[1].toString())}';

    Directory directory = Directory(path);
    File file = File('${directory.path}/${hash.toString()}');
    if (!file.existsSync()) {
      if (!create) {
        return Future.value(null);
      } else {
        file.createSync(recursive: true);
      }
    }

    return Future.value(file);
  }

  Digest _makeHash(String key) {
    var secKey = utf8.encode(_secretKey);
    var bytes = utf8.encode(key);
    var hmacSha256 = Hmac(sha256, secKey);
    return hmacSha256.convert(bytes);
  }

  String twoDigest(String str) {
    return str.length == 1 ? '0$str' : str;
  }
}
