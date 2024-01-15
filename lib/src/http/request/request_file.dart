import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:vania/vania.dart';

class RequestFile {
  final String filename;
  final String filetype;
  final MimeMultipart stream;
  Uint8List? _bytes;

  /// Get file extension
  /// eg. png, jpeg, pdf
  String get extension =>
      path.extension(filename).toLowerCase().replaceFirst('.', '');

  RequestFile({
    required this.filename,
    required this.filetype,
    required this.stream,
  });

  /// get file content in bytes
  /// ```
  /// await file.bytes
  /// ```
  Future<Uint8List> get bytes async {
    _bytes ??= await _convertMultipartToBytes(stream);
    return _bytes!;
  }

  /// get file size in kilobytes
  /// ```
  /// await file.size
  /// ```
  Future<num> get size async {
    return _getFileSize(await bytes);
  }

  /// this function will store the file in your project storage folder
  ///
  /// ```
  /// RequestFile image = req.input('image');
  /// String filename = await image.store();
  /// ```
  Future<String> store(
      {required String path, required String filename}) async {
    path = path.endsWith("/") ? path : "$path/";
    return Storage().put(path, filename, await bytes);
  }

  num _getFileSize(Uint8List bytesList) =>
      bytesList.reduce((int value, int element) => value + element);

  /// convert mimeMultipart To bytes
  Future<Uint8List> _convertMultipartToBytes(MimeMultipart multipart) async {
    List<int> partBytesList = <int>[];

    await for (List<int> part in multipart) {
      List<int> partBytes = part.toList();
      partBytesList.addAll(partBytes);
    }

    // Combine all the bytes from individual parts into a single Uint8List
    Uint8List uint8list = Uint8List.fromList(
      partBytesList.map((int byte) => byte).toList(),
    );

    return uint8list;
  }
}
