import 'dart:io';
import 'dart:typed_data';

import 'package:vania/src/storage/storage_driver.dart';
import 'package:vania/src/utils/functions.dart';

class LocalStorage implements StorageDriver {
  String storagePath = "${Directory.current.path}/storage/app/public";

  @override
  Future<bool> exists(String filename) {
    File file = File(sanitizeRoutePath('$storagePath/$filename'));
    return file.exists();
  }

  @override
  Future<Uint8List?> get(String filename) async {
    File file = File(sanitizeRoutePath('$storagePath/$filename'));
    if (file.existsSync()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<dynamic> delete(String filename) async {
    File file = File(sanitizeRoutePath('$storagePath/$filename'));
    if (file.existsSync()) {
      return await file.delete();
    }
  }

  @override
  Future<String> put(
    String filePath,
    dynamic content,
  ) async {
    String path = sanitizeRoutePath('$storagePath/$filePath');
    File file = File(path);
    Directory directory = Directory(file.parent.path);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    if (content is List<int>) {
      file.writeAsBytesSync(content);
    }

    if (content is String) {
      file.writeAsStringSync(content);
    }

    return file.path.replaceFirst(storagePath, '');
  }

  @override
  String fullPath(String file) => "$storagePath/$file";
}
