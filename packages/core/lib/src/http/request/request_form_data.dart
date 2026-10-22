import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';

import 'package:vania/src/utils/helper.dart' show abort;

import 'request_file.dart';

final RegExp _dispositionParam = RegExp(r'([\w\-]+)="([^"]*)"');

/// Handles extraction of multipart/form-data requests into a simple
/// Map of field names to either String/int or RequestFile instances.
class RequestFormData {
  final HttpRequest request;
  final Map<String, dynamic> inputs = <String, dynamic>{};

  /// Largest body accepted, counted as it streams in. A chunked upload
  /// declares no length up front, so this is the only check it meets.
  final int? maxBodySize;

  RequestFormData({required this.request, this.maxBodySize});

  /// Parse and collect all form-data parts from the request.
  /// - For text fields: decodes UTF-8 and converts to int if possible.
  /// - For file fields: wraps them in a RequestFile.
  Future<RequestFormData> extractData() async {
    final boundary = request.headers.contentType?.parameters['boundary'];
    if (boundary == null) {
      throw HttpException('Missing multipart boundary', uri: request.uri);
    }

    final transformer = MimeMultipartTransformer(boundary);
    final source = request.cast<List<int>>();

    final max = maxBodySize;
    if (max == null) {
      await _collect(source.transform(transformer));
      return this;
    }

    // Reading stops at the first chunk past the cap. The parser cannot be
    // relied on to finish after that: a part cut short is never closed, so
    // anything still reading it would wait forever. The cut is raced
    // against the parse instead.
    final tooLarge = Completer<void>();
    var received = 0;
    final capped = source.takeWhile((chunk) {
      received += chunk.length;
      if (received <= max) return true;
      tooLarge.complete();
      return false;
    });

    try {
      await Future.any([
        _collect(capped.transform(transformer)),
        tooLarge.future,
      ]);
    } catch (_) {
      if (!tooLarge.isCompleted) rethrow;
    }
    if (tooLarge.isCompleted) {
      abort(
        413,
        'Request body too large: streamed $received bytes (max $max bytes)',
      );
    }
    return this;
  }

  Future<void> _collect(Stream<MimeMultipart> parts) async {
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
  }
}
