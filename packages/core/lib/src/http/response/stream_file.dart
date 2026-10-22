import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class StreamFile {
  final String fileName;
  final Uint8List bytes;
  StreamFile({required this.fileName, required this.bytes});

  ContentType? _contentType;
  Stream<List<int>>? _stream;
  int _length = 0;

  ContentType get contentType =>
      _contentType ?? ContentType('application', 'octet-stream');

  Stream<List<int>>? get stream => _stream;
  int get length => _length;

  String get contentDisposition => attachmentDisposition(fileName);

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

/// Bytes RFC 8187 lets through `filename*` unencoded: `attr-char`.
final RegExp _attrChar = RegExp(r"[A-Za-z0-9!#$&+\-.^_`|~]");

/// A `Content-Disposition: attachment` value for [fileName] that any name
/// survives.
///
/// HTTP header values are Latin-1, so a name outside printable ASCII — a
/// Persian one, say — cannot go in `filename` as it is. It goes in
/// `filename*` as UTF-8 (RFC 6266, RFC 8187), which browsers prefer, and
/// `filename` gets an ASCII stand-in for clients that do not read it.
/// Quotes, backslashes and control characters never reach the header, so
/// a name cannot end the value early or add a header of its own.
String attachmentDisposition(String fileName) {
  final name = path.basename(fileName);
  final ascii = name.replaceAll(RegExp(r'[^\x20-\x7E]|["\\]'), '_');
  if (ascii == name) return 'attachment; filename="$name"';

  final encoded = StringBuffer();
  for (final byte in utf8.encode(name)) {
    final char = String.fromCharCode(byte);
    encoded.write(
      byte < 0x80 && _attrChar.hasMatch(char)
          ? char
          : '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
    );
  }
  return "attachment; filename=\"$ascii\"; filename*=UTF-8''$encoded";
}
