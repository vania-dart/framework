import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:vania/src/storage/storage_driver.dart';
import 'package:vania/src/utils/functions.dart';

class LocalStorage implements StorageDriver {
  String storagePath = "storage/app/public";

  @override
  Future<bool> exists(String filename) async {
    File file = File(sanitizeRoutePath('$storagePath/$filename'));
    return file.existsSync();
  }

  @override
  Future<String?> get(String filename) async {
    File file = File(sanitizeRoutePath('$storagePath/$filename'));
    if (file.existsSync()) {
      return file.readAsStringSync();
    }
    return null;
  }

  @override
  Future<Uint8List?> getAsBytes(String filename) async {
    File file = File(sanitizeRoutePath('$storagePath/$filename'));
    if (file.existsSync()) {
      return file.readAsBytesSync();
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> json(String filename) async {
    File file = File(sanitizeRoutePath('$storagePath/$filename'));
    if (file.existsSync()) {
      return jsonDecode(file.readAsStringSync());
    }
    return null;
  }

  @override
  Future<bool> delete(String filename) async {
    File file = File(sanitizeRoutePath('$storagePath/$filename'));
    if (file.existsSync()) {
      file.deleteSync();
      return true;
    } else {
      return false;
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

  @override
  Future<String?> mimeType(String filename) async {
    File file = File(sanitizeRoutePath('$storagePath/$filename'));
    if (file.existsSync()) {
      final dataBytes = file.readAsBytesSync();
      String? mimeType =
          lookupMimeType(file.uri.pathSegments.last, headerBytes: dataBytes);
      return Future.value(mimeType);
    }
    return null;
  }

  @override
  Future<num?> size(String filename) async {
    File file = File(sanitizeRoutePath('$storagePath/$filename'));
    if (file.existsSync()) {
      final dataBytes = file.readAsBytesSync();
      return dataBytes.length;
    }
    return null;
  }
}
