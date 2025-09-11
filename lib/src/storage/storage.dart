import 'dart:typed_data';

import 'package:vania/src/storage/local_storage.dart';
import 'package:vania/src/storage/s3_storage.dart';

import 'storage_driver.dart';

import 'package:vania/src/utils/helper.dart' show env;
import 'package:path/path.dart' as path;

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

  static Future<String> put(
    String directory,
    String file,
    dynamic content,
  ) async {
    if (content == null) {
      throw Exception("Content can't be null");
    }

    String fullPath = path.join(directory, file);

    if (content is List<int>) {
      return Storage()._driver.put(fullPath, content);
    } else if (content is String) {
      return Storage()._driver.put(fullPath, content);
    } else if (content is Stream<List<int>>) {
      final data = await content.fold<List<int>>([], (previous, element) {
        previous.addAll(element);
        return previous;
      });
      return Storage()._driver.put(fullPath, data);
    } else {
      throw Exception(
          'Content must be a list of int, a string, or a Stream<List<int>>.');
    }
  }

  static Future<String?> mimeType(String file) async {
    return await Storage()._driver.mimeType(file);
  }

  static Future<num?> size(String file) async {
    return Storage()._driver.size(file);
  }
}
