import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:vania/src/utils/functions.dart';
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

  /// Returns the original file name.
  /// It is extracted from the request from which the file has been uploaded.
  /// This should not be considered as a safe value to use for a file name on your servers.
  String get getClientOriginalName => filename;

  /// Returns the original file extension.
  /// It is extracted from the original file name that was uploaded.
  /// This should not be considered as a safe value to use for a file name on your servers.
  String get getClientOriginalExtension => filename.split('.').last;

  /// Returns the file mime type.
  /// The client mime type is extracted from the request from which the file
  /// was uploaded, so it should not be considered as a safe value.
  String get getClientMimeType => filetype;

  /// this function will store the file in your project storage folder
  ///
  /// ```
  /// RequestFile image = req.input('image');
  /// String filename = await image.store();
  /// ```
  Future<String> store({required String path, required String filename}) async {
    path = path.endsWith("/") ? path : "$path/";
    return Storage.put(path, filename, await bytes);
  }

  /// this function will upload the file in your project custom path
  ///
  /// ```
  /// RequestFile image = req.input('image');
  /// String filename = await image.move('/public/images','myImage.jpg');
  /// ```
  Future<String> move({required String path, required String filename}) async {
    path = sanitizeRoutePath('${Directory.current.path}/$path/$filename');
    File file = File(path);
    Directory directory = Directory(file.parent.path);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    await file.writeAsBytes(await bytes);
    if (path.startsWith('/public')) {
      return '$path/$filename'.replaceFirst('/public', '');
    }
    return '$path/$filename'.replaceFirst('public', '');
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
