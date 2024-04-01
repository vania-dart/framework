import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:vania/src/extensions/string_extension.dart';
import 'package:vania/vania.dart';

class LocalCacheDriver implements CacheDriver {
  final String _secretKey = env('APP_KEY');

  final String cachePath = 'storage/framework/cache/data';

  @override
  Future<void> delete(String key) async {
    File? file = await _cacheFile(key);
    file?.deleteSync();
  }

  @override
  Future<String?> get(String key) async {
    Map<String, dynamic>? data = await _getData(key);
    int expiration = data?['expiration'].toString().toInt() ?? 0;
    if (!DateTime.now()
        .toUtc()
        .isBefore(DateTime.fromMillisecondsSinceEpoch(expiration))) {
      return Future.value(null);
    }
    return Future.value(data?['data']);
  }

  @override
  Future<bool> has(String key) async {
    File? file = await _cacheFile(key);
    return Future.value(file?.exists());
  }

  @override
  Future<void> put(
    String key,
    String value, {
    Duration? duration,
  }) async {
    duration ?? Duration(hours: 1);
    int expiration = DateTime.now().toUtc().millisecondsSinceEpoch +
        (duration?.inMilliseconds ?? 0);
    Map<String, dynamic> data = {'data': value, 'expiration': expiration};
    _writeData(key, json.encode(data));
  }

  @override
  Future<void> forever(
    String key,
    String value,
  ) async {
    Duration duration = Duration(days: 999999);
    int expiration =
        DateTime.now().toUtc().millisecondsSinceEpoch + duration.inMilliseconds;
    Map<String, dynamic> data = {'data': value, 'expiration': expiration};
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
        '${Directory.current.path}/$cachePath/${twoDigest(hash.bytes[0].toString())}/${twoDigest(hash.bytes[1].toString())}';

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
