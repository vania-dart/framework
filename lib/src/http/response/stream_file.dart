import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class StreamFile {
  final String fileName;
  final Uint8List bytes;
  StreamFile({
    required this.fileName,
    required this.bytes,
  });

  ContentType? _contentType;
  Stream<List<int>>? _stream;
  int _length = 0;

  ContentType get contentType =>
      _contentType ?? ContentType('application', 'octet-stream');

  Stream<List<int>>? get stream => _stream;
  int get length => _length;

  String get contentDisposition =>
      'attachment; filename="${path.basename(fileName)}"';

  StreamFile? call() {
    String mimeType =
        lookupMimeType(path.basename(fileName), headerBytes: bytes) ?? "";

    String primaryType = mimeType.split('/').first;
    String subType = mimeType.split('/').last;

    _contentType = ContentType(primaryType, subType);

    _stream = Stream<List<int>>.fromIterable([bytes]);

    _length = bytes.length;

    return this;
  }
}
