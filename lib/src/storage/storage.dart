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
  String? _disk;

  Map<String, StorageDriver> storageDriver = <String, StorageDriver>{
    'local': LocalStorage(),
    ...Config().get("storage").drivers
  };

  Storage disk(String disk) {
    _disk = disk;
    return this;
  }

  StorageDriver get _driver {
    return storageDriver[_disk] ??
        storageDriver[Config().get("storage").defaultDriver] ??
        LocalStorage();
  }

  Future delete(String filepath) {
    return _driver.delete(filepath);
  }

  Future<bool> exists(String filename) {
    File file = File(filename);
    return file.exists();
  }

  Future<Uint8List?> get(String filename) async {
    File file = File((filename));
    if (file.existsSync()) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<String> put(String folder, String fileName, List<int> bytes) {
    folder = folder.endsWith("/") ? folder : "$folder/";
    String path = '$folder$fileName';
    return _driver.put(path, bytes);
  }

  Future<DownloadFile?> downloadFile(String filename) async {
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
