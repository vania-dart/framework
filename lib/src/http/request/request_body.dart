import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:vania/src/http/request/request_form_data.dart';
import 'package:vania/src/utils/helper.dart' show abort;
import 'package:vania/vania.dart' show env;

class RequestBody {
  const RequestBody();

  static final int _maxBodySizeBytes =
      env<int>('MAX_BODY_SIZE', 10 * 1024 * 1024);

  static Future<Map<String, dynamic>> extractBody({
    required HttpRequest request,
  }) async {
    final headers = request.headers;
    final contentLength = headers.contentLength;

    if (contentLength > _maxBodySizeBytes) {
      abort(
        413,
        'Request body too large:  $contentLength bytes (max $_maxBodySizeBytes bytes)',
      );
    }

    if (isFormData(request.headers.contentType)) {
      final formData = RequestFormData(request: request);
      await formData.extractData();
      return formData.inputs;
    }

    final bytesBuilder = BytesBuilder();
    await for (final chunk in request) {
      bytesBuilder.add(chunk);
    }
    final bodyBytes = bytesBuilder.takeBytes();
    final bodyString = utf8.decode(bodyBytes);

    if (isJson(request.headers.contentType)) {
      try {
        final decoded = jsonDecode(bodyString);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
      return <String, dynamic>{};
    }

    if (isUrlencoded(request.headers.contentType)) {
      try {
        return Uri.splitQueryString(bodyString);
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    return <String, dynamic>{};
  }

  static bool isUrlencoded(ContentType? contentType) {
    return contentType?.mimeType.toLowerCase().contains('urlencoded') == true;
  }

  static bool isFormData(ContentType? contentType) {
    return contentType?.mimeType.toLowerCase().contains('form-data') == true;
  }

  static bool isJson(ContentType? contentType) {
    return contentType?.mimeType.toLowerCase().contains('json') == true;
  }
}
