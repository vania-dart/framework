import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class StreamFile {
  final String filename;
  StreamFile({required this.filename});

  ContentType? _contentType;
  Stream<List<int>>? _stream;
  int _length = 0;

  ContentType get contentType =>
      _contentType ?? ContentType('application', 'octet-stream');

  Stream<List<int>>? get stream => _stream;
  int get length => _length;

  String get contentDisposition =>
      'attachment; filename="${path.basename(filename)}"';

  StreamFile? call() {
    File file = File(filename);

    if (!file.existsSync()) {
      return null;
    } else {
      List<int>? bytes = file.readAsBytesSync();
      String mimeType =
          lookupMimeType(path.basename(filename), headerBytes: bytes) ?? "";

      String primaryType = mimeType.split('/').first;
      String subType = mimeType.split('/').last;

      _contentType = ContentType(primaryType, subType);
      _stream = Stream<List<int>>.fromIterable([bytes]);
      _length = bytes.length;
    }
    return this;
  }
}
