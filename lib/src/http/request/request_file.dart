import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:vania/src/storage/storage.dart';
import 'package:vania/src/utils/functions.dart';

/// Represents an uploaded file part from multipart/form-data.
/// Provides lazy access to bytes, size, and easy storage/move.
class RequestFile {
  final String filename;
  final String filetype;
  final MimeMultipart stream;
  Uint8List? _bytes;

  RequestFile({
    required this.filename,
    required this.filetype,
    required this.stream,
  });

  /// File extension without the dot (e.g. "png", "jpg", "pdf").
  String get extension {
    final idx = filename.lastIndexOf('.');
    return (idx >= 0 && idx < filename.length - 1)
        ? filename.substring(idx + 1).toLowerCase()
        : '';
  }

  /// Lazily reads all bytes from the multipart stream.
  Future<Uint8List> get bytes async {
    if (_bytes != null) return _bytes!;
    final builder = BytesBuilder();
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    _bytes = builder.takeBytes();
    return _bytes!;
  }

  /// Returns the file size in bytes.
  Future<int> get size async {
    final b = await bytes;
    return b.length;
  }

  /// Original client‐provided file name.
  String get clientOriginalName => filename;

  /// Original client‐provided file extension.
  String get clientOriginalExtension => extension;

  /// Original client‐provided MIME type.
  String get clientMimeType => filetype;

  /// Store the file via your Storage layer.
  /// - `destPath` should include trailing slash if desired.
  Future<String> store({String path = '', required String name}) async {
    try {
      final content = await bytes;
      return await Storage.put(path, name, content.toList());
    } catch (e) {
      throw FileSystemException('Failed to store file as $name: $e');
    }
  }

  /// Move the file into a local path on disk.
  /// Creates directories as needed.
  Future<String> move({required String toPath, required String name}) async {
    final fullPath = sanitizeRoutePath('$toPath/$name');
    final file = File(fullPath);
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    await for (final chunk in stream) {
      sink.add(chunk);
    }
    await sink.close();

    // strip leading /public if used
    return fullPath.replaceFirst(RegExp(r'^/?public'), '');
  }
}
