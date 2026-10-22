import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:vania/src/exception/http_exception.dart';
import 'package:vania/src/http/request/request_form_data.dart';
import 'package:vania/src/utils/helper.dart' show abort;
import 'package:vania/env.dart' show env;

final Converter<List<int>, Object?> _utf8Json = utf8.decoder.fuse(json.decoder);

class RequestBody {
  const RequestBody();

  static final int _maxBodySizeBytes = env<int>(
    'MAX_BODY_SIZE',
    10 * 1024 * 1024,
  );

  static Future<Map<String, dynamic>> extractBody({
    required HttpRequest request,
  }) async => (await extract(request: request)).fields;

  /// Reads the request content: [RequestContent.fields] parsed from a
  /// form or JSON body, and [RequestContent.bytes] as received.
  ///
  /// Content that does not parse as its declared type yields no fields.
  /// With [strict] it is a 400 instead: RFC 10008 has a `QUERY` server
  /// reject content that contradicts its `Content-Type`, since the query
  /// is that content and there is nothing else to fall back on.
  static Future<RequestContent> extract({
    required HttpRequest request,
    bool strict = false,
  }) async {
    final headers = request.headers;
    final contentLength = headers.contentLength;

    // Reject up-front when the client declares a body larger than the cap.
    if (contentLength > _maxBodySizeBytes) {
      abort(
        413,
        'Request body too large: $contentLength bytes (max $_maxBodySizeBytes bytes)',
      );
    }

    final contentType = request.headers.contentType;
    if (isFormData(contentType)) {
      final formData = RequestFormData(
        request: request,
        maxBodySize: _maxBodySizeBytes,
      );
      try {
        await formData.extractData();
      } on HttpResponseException {
        rethrow;
      } catch (_) {
        if (strict) abort(400, 'The content is not valid multipart data.');
        rethrow;
      }
      // Parts are streamed rather than buffered, so there are no bytes to
      // keep.
      return RequestContent(formData.inputs, Uint8List(0));
    }

    final Uint8List bodyBytes = await _drain(request, contentLength);

    if (bodyBytes.isEmpty) return RequestContent({}, bodyBytes);

    if (isJson(contentType)) {
      try {
        final decoded = _utf8Json.convert(bodyBytes);
        if (decoded is Map<String, dynamic>) {
          return RequestContent(decoded, bodyBytes);
        }
        if (decoded is Map) {
          return RequestContent(decoded.cast<String, dynamic>(), bodyBytes);
        }
        // Valid JSON that is not an object has no fields to offer.
        return RequestContent({}, bodyBytes);
      } catch (_) {
        if (strict) abort(400, 'The content is not valid JSON.');
        return RequestContent({}, bodyBytes);
      }
    }

    if (isUrlencoded(contentType)) {
      try {
        return RequestContent(
          Uri.splitQueryString(utf8.decode(bodyBytes)),
          bodyBytes,
        );
      } catch (_) {
        if (strict) abort(400, 'The content is not valid form data.');
        return RequestContent({}, bodyBytes);
      }
    }

    return RequestContent({}, bodyBytes);
  }

  static Future<Uint8List> _drain(
    HttpRequest request,
    int contentLength,
  ) async {
    // Cap for the pre-sized fast path. Anything above this we still
    // stream (with the same DoS cap) but through a BytesBuilder to
    // avoid a giant up-front allocation on a possibly-lying header.
    const preAllocCap = 512 * 1024; // 512 KiB

    if (contentLength > 0 && contentLength <= preAllocCap) {
      final buf = Uint8List(contentLength);
      var offset = 0;
      await for (final chunk in request) {
        final need = offset + chunk.length;
        if (need > _maxBodySizeBytes) {
          abort(
            413,
            'Request body too large: streamed $need bytes (max $_maxBodySizeBytes bytes)',
          );
        }
        if (need <= buf.length) {
          buf.setRange(offset, need, chunk);
          offset = need;
        } else {
          // Client sent more bytes than the header promised — fall back
          // to a builder to accommodate the rest without corrupting
          // what we already read.
          final builder = BytesBuilder()..add(buf.sublist(0, offset));
          builder.add(chunk);
          var acc = need;
          await for (final more in request) {
            acc += more.length;
            if (acc > _maxBodySizeBytes) {
              abort(
                413,
                'Request body too large: streamed $acc bytes (max $_maxBodySizeBytes bytes)',
              );
            }
            builder.add(more);
          }
          return builder.takeBytes();
        }
      }
      // If the client sent fewer bytes than promised, return the
      // populated prefix as-is so downstream parsers see the truncated
      // payload rather than trailing zeros.
      return offset == buf.length ? buf : Uint8List.sublistView(buf, 0, offset);
    }

    // Unknown or huge content length: stream with the same cap.
    final builder = BytesBuilder(copy: false);
    var accumulated = 0;
    await for (final chunk in request) {
      accumulated += chunk.length;
      if (accumulated > _maxBodySizeBytes) {
        abort(
          413,
          'Request body too large: streamed $accumulated bytes (max $_maxBodySizeBytes bytes)',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static bool isUrlencoded(ContentType? contentType) {
    final mime = contentType?.mimeType;
    if (mime == null) return false;
    return mime.contains('urlencoded');
  }

  static bool isFormData(ContentType? contentType) {
    final mime = contentType?.mimeType;
    if (mime == null) return false;
    return mime.contains('form-data');
  }

  static bool isJson(ContentType? contentType) {
    final mime = contentType?.mimeType;
    if (mime == null) return false;
    return mime.contains('json');
  }
}

/// A request body as read by [RequestBody.extract].
class RequestContent {
  /// Fields parsed from a form or JSON object; empty for anything else.
  final Map<String, dynamic> fields;

  /// The content as received. Empty for multipart, which is streamed.
  final Uint8List bytes;

  const RequestContent(this.fields, this.bytes);
}
