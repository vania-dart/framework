import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:vania/src/aws/s3_client.dart';
import 'storage_driver.dart';

class S3Storage implements StorageDriver {
  static final S3Storage _instance = S3Storage._internal();
  factory S3Storage() => _instance;
  S3Storage._internal();

  final S3Client _s3Client = S3Client();
  final Map<String, _CachedMetadata> _metadataCache = {};
  static const Duration _metadataCacheDuration = Duration(minutes: 5);

  String removeLeadingSlash(String file) {
    return file.startsWith('/') ? file.replaceFirst('/', '') : file;
  }

  @override
  String fullPath(String file) {
    return _s3Client.buildUri(file).toString();
  }

  @override
  Future<String> put(String filePath, dynamic content) async {
    filePath = removeLeadingSlash(filePath);
    final uri = _s3Client.buildUri(filePath);

    final client = HttpClient();
    try {
      final request = await client.putUrl(uri);
      final contentType =
          lookupMimeType(filePath) ?? 'application/octet-stream';
      request.headers.set('Content-Type', contentType);
      request.headers.set('Content-Length', content.length.toString());

      final payloadHash = sha256.convert(content).toString();
      _s3Client
          .generateS3Headers('PUT', filePath, hash: payloadHash)
          .forEach((key, value) => request.headers.set(key, value));

      request.add(content);
      final response = await request.close();

      if (response.statusCode == 200) {
        _invalidateMetadataCache(filePath);
        return uri.toString();
      }
      throw Exception('Failed to upload file: ${response.statusCode}');
    } finally {
      client.close();
    }
  }

  @override
  Future<String?> get(String file) async {
    file = removeLeadingSlash(file);
    final client = HttpClient();
    try {
      final response = await _executeRequest(client, 'GET', file);
      if (response.statusCode == 200) {
        return await response.transform(utf8.decoder).join();
      }
      return null;
    } finally {
      client.close();
    }
  }

  @override
  Future<Uint8List?> getAsBytes(String file) async {
    file = removeLeadingSlash(file);
    final client = HttpClient();
    try {
      final response = await _executeRequest(client, 'GET', file);
      if (response.statusCode == 200) {
        return await response
            .fold<BytesBuilder>(BytesBuilder(), (b, d) => b..add(d))
            .then((b) => b.takeBytes());
      }
      return null;
    } finally {
      client.close();
    }
  }

  @override
  Future<Map<String, dynamic>?> json(String file) async {
    final content = await get(removeLeadingSlash(file));
    if (content == null) return null;

    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> mimeType(String file) async {
    final metadata = await _getMetadata(file);
    if (metadata?.contentType != null) {
      return metadata!.contentType;
    }

    final bytes = await getAsBytes(file);
    if (bytes != null) {
      return lookupMimeType(
        file,
        headerBytes: bytes.sublist(0, min(4096, bytes.length)),
      );
    }
    return null;
  }

  @override
  Future<num?> size(String file) async {
    final metadata = await _getMetadata(file);
    return metadata?.contentLength;
  }

  @override
  Future<bool> exists(String file) async {
    final metadata = await _getMetadata(file);
    return metadata != null;
  }

  @override
  Future<bool> delete(String file) async {
    file = removeLeadingSlash(file);
    final client = HttpClient();
    try {
      final response = await _executeRequest(client, 'DELETE', file);
      final success = response.statusCode == 204;
      if (success) {
        _invalidateMetadataCache(file);
      }
      return success;
    } finally {
      client.close();
    }
  }

  Future<HttpClientResponse> _executeRequest(
    HttpClient client,
    String method,
    String file,
  ) async {
    final uri = _s3Client.buildUri(file);
    final request = await _getRequestForMethod(client, method, uri);

    _s3Client
        .generateS3Headers(method, file)
        .forEach((key, value) => request.headers.set(key, value));

    return await request.close();
  }

  Future<HttpClientRequest> _getRequestForMethod(
    HttpClient client,
    String method,
    Uri uri,
  ) async {
    switch (method) {
      case 'GET':
        return await client.getUrl(uri);
      case 'PUT':
        return await client.putUrl(uri);
      case 'DELETE':
        return await client.deleteUrl(uri);
      case 'HEAD':
        return await client.headUrl(uri);
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }
  }

  Future<_CachedMetadata?> _getMetadata(String file) async {
    file = removeLeadingSlash(file);

    // Check cache first
    final cached = _metadataCache[file];
    if (cached != null && !cached.isExpired) {
      return cached;
    }
    final client = HttpClient();
    try {
      final response = await _executeRequest(client, 'HEAD', file);
      if (response.statusCode != 200) return null;

      final metadata = _CachedMetadata(
        contentLength: int.tryParse(
          response.headers.value('content-length') ?? '',
        ),
        contentType: response.headers.value('content-type'),
        lastModified: response.headers.value('last-modified'),
      );

      _metadataCache[file] = metadata;
      return metadata;
    } finally {
      client.close();
    }
  }

  void _invalidateMetadataCache(String file) {
    _metadataCache.remove(file);
  }
}

class _CachedMetadata {
  final num? contentLength;
  final String? contentType;
  final String? lastModified;
  final DateTime cacheTime;

  _CachedMetadata({this.contentLength, this.contentType, this.lastModified})
    : cacheTime = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(cacheTime) > S3Storage._metadataCacheDuration;
}
