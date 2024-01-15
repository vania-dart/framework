import 'dart:typed_data';

abstract class StorageDriver {
  Future<String> put(
    String filePath,
    List<int> bytes,
  );

  Future<Uint8List?> get(String filepath);

  Future<bool> exists(String filepath);

  Future<dynamic> delete(String filepath);
}
