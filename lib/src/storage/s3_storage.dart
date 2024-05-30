import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:vania/src/aws/s3_client.dart';

import 'storage_driver.dart';

class S3Storage implements StorageDriver {
  String removeLeadingSlash(String file) {
    return file.startsWith('/') ? file.replaceFirst('/', '') : file;
  }

  @override
  String fullPath(String file) {
    return S3Client().buildUri(file).toString();
  }

  @override
  Future<String> put(String filePath, dynamic content) async {
    final HttpClient client = HttpClient();
    filePath = removeLeadingSlash(filePath);
    var uri = S3Client().buildUri(filePath);
    final request = await client.putUrl(uri);
    request.headers.set(
      'Content-Type',
      lookupMimeType(filePath) ?? 'application/octet-stream',
    );
    request.headers.set(
      'Content-Length',
      content.length.toString(),
    );
    final payloadHash = sha256.convert(content).toString();
    S3Client()
        .generateS3Headers('PUT', filePath, hash: payloadHash)
        .forEach((key, value) {
      request.headers.set(key, value);
    });

    request.add(content);

    var response = await request.close();
    //String reply = await response.transform(utf8.decoder).join();

    client.close();
    if (response.statusCode == 200) {
      return uri.toString();
    } else {
      throw Exception('Failed to upload file: ${response.statusCode}');
    }
  }

  @override
  Future<String?> get(String file) async {
    final HttpClient client = HttpClient();
    file = removeLeadingSlash(file);
    var uri = S3Client().buildUri(file);
    var request = await client.getUrl(uri);
    S3Client().generateS3Headers('GET', file).forEach((key, value) {
      request.headers.set(key, value);
    });
    var response = await request.close();
    client.close();
    if (response.statusCode == 200) {
      return await response.transform(utf8.decoder).join();
    } else {
      return null;
    }
  }

  @override
  Future<Uint8List?> getAsBytes(String file) async {
    final HttpClient client = HttpClient();
    file = removeLeadingSlash(file);
    var uri = S3Client().buildUri(file);
    var request = await client.getUrl(uri);
    S3Client().generateS3Headers('GET', file).forEach((key, value) {
      request.headers.set(key, value);
    });
    var response = await request.close();
    client.close();
    if (response.statusCode == 200) {
      var bytes = await response
          .fold<BytesBuilder>(BytesBuilder(), (b, d) => b..add(d))
          .then((b) => b.takeBytes());
      return Uint8List.fromList(bytes);
    } else {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>?> json(String file) async {
    file = removeLeadingSlash(file);
    var str = await get(file);
    return str == null ? null : jsonDecode(str);
  }

  @override
  Future<String?> mimeType(String file) async {
    file = removeLeadingSlash(file);
    var bytes = await getAsBytes(file);
    if (bytes != null) {
      return lookupMimeType(file,
          headerBytes: bytes.sublist(0, min(4096, bytes.length)));
    }
    return null;
  }

  @override
  Future<num?> size(String file) async {
    final HttpClient client = HttpClient();
    file = removeLeadingSlash(file);
    var uri = S3Client().buildUri(file);
    var request = await client.headUrl(uri);
    S3Client().generateS3Headers('HEAD', file).forEach((key, value) {
      request.headers.set(key, value);
    });
    var response = await request.close();
    client.close();
    if (response.statusCode == 200) {
      return int.tryParse(response.headers.value('content-length') ?? '');
    } else {
      return null;
    }
  }

  @override
  Future<bool> exists(String file) async {
    final HttpClient client = HttpClient();
    var uri = S3Client().buildUri(file);
    var request = await client.headUrl(uri);
    S3Client().generateS3Headers('HEAD', file).forEach((key, value) {
      request.headers.set(key, value);
    });
    var response = await request.close();
    client.close();
    return response.statusCode == 200;
  }

  @override
  Future<bool> delete(String file) async {
    final HttpClient client = HttpClient();
    var uri = S3Client().buildUri(file);
    var request = await client.deleteUrl(uri);
    S3Client().generateS3Headers('DELETE', file).forEach((key, value) {
      request.headers.set(key, value);
    });
    var response = await request.close();
    client.close();
    return response.statusCode == 204;
  }
}
