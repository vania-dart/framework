import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import '../performance/_task_manager.dart';
import '../utils/helper.dart';
import 'storage_driver.dart';

class LocalStorage implements StorageDriver {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  final TaskManager _taskManager = TaskManager();
  final String _storageDir = storagePath('app/public');
  static const Duration _defaultTimeout = Duration(seconds: 30);

  @override
  Future<bool> delete(String file) async {
    final targetFile = File(path.join(_storageDir, file));
    if (!await targetFile.exists()) return false;

    try {
      await _taskManager.runInIsolate(
        () async => await targetFile.delete(),
        timeout: _defaultTimeout,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> exists(String file) async {
    return await File(path.join(_storageDir, file)).exists();
  }

  @override
  Future<Uint8List?> getAsBytes(String file) async {
    final targetFile = File(path.join(_storageDir, file));
    if (!await targetFile.exists()) return null;

    try {
      return await _taskManager.runInIsolate(
        () => targetFile.readAsBytes(),
        timeout: _defaultTimeout,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> get(String file) async {
    final targetFile = File(path.join(_storageDir, file));
    if (!await targetFile.exists()) return null;

    try {
      return await _taskManager.runInIsolate(
        () => targetFile.readAsString(),
        timeout: _defaultTimeout,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> json(String file) async {
    final content = await get(file);
    if (content == null) return null;

    try {
      return await _taskManager.runInIsolate(
        () async => jsonDecode(content) as Map<String, dynamic>,
        timeout: _defaultTimeout,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String> put(String path, dynamic content) async {
    final targetFile = File(_getFullPath(path));
    await _ensureDirectoryExists(targetFile.parent);

    try {
      await _taskManager.runInIsolate(
        () async {
          if (content is List<int>) {
            await targetFile.writeAsBytes(content);
          } else {
            await targetFile.writeAsString(content.toString());
          }
        },
        timeout: _defaultTimeout,
      );
      return path;
    } catch (e) {
      throw Exception('Failed to write file: $e');
    }
  }

  @override
  Future<String?> mimeType(String file) async {
    final targetFile = File(path.join(_storageDir, file));
    if (!await targetFile.exists()) return null;

    try {
      final bytes = await targetFile.readAsBytes();
      return lookupMimeType(file, headerBytes: bytes);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<num?> size(String file) async {
    final targetFile = File(path.join(_storageDir, file));
    if (!await targetFile.exists()) return null;

    try {
      return await _taskManager.runInIsolate(
        () => targetFile.length(),
        timeout: _defaultTimeout,
      );
    } catch (e) {
      return null;
    }
  }

  String _getFullPath(String filePath) {
    return path.join(_storageDir, filePath);
  }

  Future<void> _ensureDirectoryExists(Directory directory) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  @override
  String fullPath(String file) => path.join(_storageDir, file);
}
