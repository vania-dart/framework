import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:vania/src/storage/local_storage.dart';
import 'package:vania/vania.dart';

class DownloadFile {
  String? fileName;
  ContentType? contentType;
  String? contentDisposition;
  Uint8List? data;
  DownloadFile(
      {this.fileName, this.contentType, this.contentDisposition, this.data});
}

class Storage {
  static final Storage _singleton = Storage._internal();
  factory Storage() => _singleton;
  Storage._internal();

  String? _disk;

  Map<String, StorageDriver> storageDriver = <String, StorageDriver>{
    'local': LocalStorage(),
    ...Config().get("storage")?.drivers
  };

  Storage disk(String disk) {
    _disk = disk;
    return this;
  }

  StorageDriver get _driver {
    return storageDriver[_disk] ??
        storageDriver[Config().get("storage")?.defaultDriver] ??
        LocalStorage();
  }

  static delete(String filepath) {
    return Storage()._driver.delete(filepath);
  }

  static Future<bool> exists(String filename) {
    File file = File(filename);
    return Future.value(file.existsSync());
  }

  static Future<Uint8List?> getAsBytes(String filename) async {
    return await Storage()._driver.getAsBytes(filename);
  }

  static Future<String?> get(String filename) async {
    return await Storage()._driver.get(filename);
  }

  static Future<Map<String, dynamic>?> json(String filename) async {
    return await Storage()._driver.json(filename);
  }

  static Future<String> put(
      String directory, String filename, dynamic content) {
    if (content == null) {
      throw Exception("Content can't bew null");
    }

    if (!(content is List<int> || content is String)) {
      throw Exception('Content must be a list of int or a string.');
    }

    directory = directory.endsWith("/") ? directory : "$directory/";
    String path = '$directory$filename';
    return Storage()._driver.put(path, content);
  }

  static Future<String?> mimeType(String filename) async {
    return await Storage()._driver.mimeType(filename);
  }

  static Future<num?> size(String filename) async {
    return Storage()._driver.size(filename);
  }

  static Future<DownloadFile?> downloadFile(String filename) async {
    File file = File((filename));
    if (file.existsSync()) {
      final dataBytes = await file.readAsBytes();
      String? mimeType =
          lookupMimeType(file.uri.pathSegments.last, headerBytes: dataBytes);
      String primaryType = mimeType!.split('/').first;
      String subType = mimeType.split('/').last;
      ContentType contentType = ContentType(primaryType, subType);

      return DownloadFile(
        fileName: file.uri.pathSegments.last,
        contentType: contentType,
        contentDisposition:
            'attachment; filename="${file.uri.pathSegments.last}"',
        data: dataBytes,
      );
    }
    return null;
  }
}
