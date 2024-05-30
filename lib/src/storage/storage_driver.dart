import 'dart:typed_data';

abstract class StorageDriver {
  Future<String> put(
    String filename,
    dynamic content,
  );

  Future<String?> get(String filename);
  Future<Uint8List?> getAsBytes(String filename);
  Future<Map<String, dynamic>?> json(String filename);
  Future<String?> mimeType(String filename);
  Future<num?> size(String filename);

  String fullPath(String file);

  Future<bool> exists(String filename);

  Future<bool> delete(String filename);
}
