import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';

import 'request_file.dart';

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

    // split request stream into MimeMultipart parts
    final transformer = MimeMultipartTransformer(boundary);
    final parts =
        await request.cast<List<int>>().transform(transformer).toList();

    for (final part in parts) {
      final disposition = part.headers['content-disposition'];
      if (disposition == null) continue;

      // Simple regex to capture name="..." and filename="..." pairs
      final params = <String, String>{};
      final regExp = RegExp(r'([\w\-]+)="([^"]*)"');
      for (final m in regExp.allMatches(disposition)) {
        params[m.group(1)!] = m.group(2)!;
      }

      final name = params['name'];
      if (name == null) continue;

      final filename = params['filename'];
      if (filename == null || filename.isEmpty) {
        // text field
        final raw = utf8.decode(await part.fold<List<int>>(
          <int>[],
          (buf, b) => buf..addAll(b),
        ));
        final value = int.tryParse(raw) ?? raw;
        if (name.endsWith('[]')) {
          final key = name.substring(0, name.length - 2);
          inputs.putIfAbsent(key, () => <dynamic>[]);
          (inputs[key] as List).add(value);
        } else {
          inputs[name] = value;
        }
      } else {
        // file field
        final file = RequestFile(
          filename: filename,
          filetype: part.headers['content-type'] ?? 'application/octet-stream',
          stream: part,
        );
        if (name.endsWith('[]')) {
          final key = name.substring(0, name.length - 2);
          inputs.putIfAbsent(key, () => <RequestFile>[]);
          (inputs[key] as List<RequestFile>).add(file);
        } else {
          inputs[name] = file;
        }
      }
    }

    return this;
  }
}
