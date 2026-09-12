import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';

import 'request_file.dart';

final RegExp _dispositionParam = RegExp(r'([\w\-]+)="([^"]*)"');

/// Handles extraction of multipart/form-data requests into a simple
/// Map of field names to either String/int or RequestFile instances.
class RequestFormData {
  final HttpRequest request;
  final Map<String, dynamic> inputs = <String, dynamic>{};

  RequestFormData({required this.request});

  /// Parse and collect all form-data parts from the request.
  /// - For text fields: decodes UTF-8 and converts to int if possible.
  /// - For file fields: wraps them in a RequestFile.
  Future<RequestFormData> extractData() async {
    final boundary = request.headers.contentType?.parameters['boundary'];
    if (boundary == null) {
      throw HttpException('Missing multipart boundary', uri: request.uri);
    }

    final transformer = MimeMultipartTransformer(boundary);
    final parts = request.cast<List<int>>().transform(transformer);

    await for (final part in parts) {
      final disposition = part.headers['content-disposition'];
      if (disposition == null) continue;

      String? name;
      String? filename;
      for (final m in _dispositionParam.allMatches(disposition)) {
        final key = m.group(1)!;
        if (key == 'name') {
          name = m.group(2);
        } else if (key == 'filename') {
          filename = m.group(2);
        }
      }
      if (name == null) continue;

      if (filename == null || filename.isEmpty) {
        final buf = BytesBuilder(copy: false);
        await for (final chunk in part) {
          buf.add(chunk);
        }
        final raw = utf8.decode(buf.takeBytes());
        final value = int.tryParse(raw) ?? raw;
        if (name.endsWith('[]')) {
          final key = name.substring(0, name.length - 2);
          final list = inputs[key];
          if (list is List) {
            list.add(value);
          } else {
            inputs[key] = <dynamic>[value];
          }
        } else {
          inputs[name] = value;
        }
      } else {
        final file = RequestFile(
          filename: filename,
          filetype: part.headers['content-type'] ?? 'application/octet-stream',
          stream: part,
        );
        if (name.endsWith('[]')) {
          final key = name.substring(0, name.length - 2);
          final list = inputs[key];
          if (list is List<RequestFile>) {
            list.add(file);
          } else {
            inputs[key] = <RequestFile>[file];
          }
        } else {
          inputs[name] = file;
        }
      }
    }

    return this;
  }
}
