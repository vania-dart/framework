import 'dart:io';
import 'dart:typed_data';

import 'package:vania/src/storage/storage_driver.dart';


class LocalStorage implements StorageDriver {
  String storagePath = "${Directory.current.path}/storage/app/public";

  @override
  Future<bool> exists(String filename) {
    File file = File(_clearName('$storagePath/$filename'));
    return file.exists();
  }

  @override
  Future<Uint8List?> get(String filename) async {
    File file = File(_clearName('$storagePath/$filename'));
    if (file.existsSync()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<dynamic> delete(String filename) async {
    File file = File(_clearName('$storagePath/$filename'));
    if (file.existsSync()) {
      return await file.delete();
    }
  }

  @override
  Future<String> put(
    String filePath,
    List<int> bytes,
  ) async {
    String path = _clearName('$storagePath/$filePath');
    File file = File(path);
    Directory directory = Directory(file.parent.path);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    await file.writeAsBytes(bytes);
    return file.path.replaceFirst(storagePath, '');
  }

  String _clearName(String path) {
    path = path.replaceAll(RegExp(r'/+'), '/');
    return "${path.replaceAll(RegExp('^\\/+|\\/+\$'), '')}";
  }
}
