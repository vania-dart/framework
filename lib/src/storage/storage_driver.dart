import 'dart:typed_data';

abstract class StorageDriver {
  Future<String> put(
    String fileName,
    List<int> bytes,
  );

  Future<Uint8List?> get(String fileName);

  String fullPath(String file);

  Future<bool> exists(String fileName);

  Future<dynamic> delete(String fileName);
}
