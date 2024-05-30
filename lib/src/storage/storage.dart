import 'dart:typed_data';

import 'package:vania/src/storage/local_storage.dart';
import 'package:vania/src/storage/s3_storage.dart';
import 'package:vania/vania.dart';

class Storage {
  static final Storage _singleton = Storage._internal();
  factory Storage() => _singleton;
  Storage._internal();

  final StorageDriver _driver = switch (env<String>('STORAGE', 'local')) {
    'local' => LocalStorage(),
    's3' => S3Storage(),
    _ => LocalStorage(),
  };

  static Future<bool> delete(String file) async {
    return await Storage()._driver.delete(file);
  }

  static Future<bool> exists(String file) async {
    return await Storage()._driver.exists(file);
  }

  static Future<Uint8List?> getAsBytes(String file) async {
    return await Storage()._driver.getAsBytes(file);
  }

  static Future<String?> get(String file) async {
    return await Storage()._driver.get(file);
  }

  static Future<Map<String, dynamic>?> json(String file) async {
    return await Storage()._driver.json(file);
  }

  static Future<String> put(String directory, String file, dynamic content) {
    if (content == null) {
      throw Exception("Content can't bew null");
    }

    if (!(content is List<int> || content is String)) {
      throw Exception('Content must be a list of int or a string.');
    }

    directory = directory.endsWith("/") ? directory : "$directory/";
    String path = '$directory$file';
    return Storage()._driver.put(path, content);
  }

  static Future<String?> mimeType(String file) async {
    return await Storage()._driver.mimeType(file);
  }

  static Future<num?> size(String file) async {
    return Storage()._driver.size(file);
  }
}
