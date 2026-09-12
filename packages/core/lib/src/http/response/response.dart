import 'dart:convert';
import 'package:vania/src/http/session/flash_messages.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:vania/src/http/response/stream_file.dart';
import 'package:vania/src/route/route_history.dart';

final Utf8Encoder _utf8 = utf8.encoder;

/// Encodes straight from the object graph to UTF-8 bytes.
///
/// `utf8.encode(jsonEncode(data))` builds a full intermediate `String` and
/// then walks it again to produce bytes. Going direct skips that middle
/// step, which is worth about a fifth of the encoding time and scales with
/// the payload. Output — including the errors thrown for unsupported and
/// cyclic values — is byte-identical to the two-step form.
final JsonUtf8Encoder _jsonUtf8 = JsonUtf8Encoder();

enum ResponseType { json, none, redirect, html, sse, streamFile, download }

class Response {
  @protected
  final ResponseType responseType;
  @protected
  final dynamic data;
  @protected
  final int httpStatusCode;
  @protected
  final Map<String, String> headers;

  Response({
    this.data,
    this.responseType = ResponseType.none,
    this.httpStatusCode = HttpStatus.ok,
    this.headers = const {},
  });

  @protected
  Future<void> sseHandler(HttpResponse res) async {
    res.headers.contentType = ContentType.parse('text/event-stream');
    res.headers.add(HttpHeaders.cacheControlHeader, 'no-cache');
    res.headers.add(HttpHeaders.connectionHeader, 'keep-alive');
    res.headers.add(HttpHeaders.transferEncodingHeader, 'chunked');

    void writeSSE(String data) {
      res.add(utf8.encode('data: $data\n\n'));
    }

    await for (var event in data) {
      writeSSE(jsonEncode(event));
      await res.flush();
    }

    await res.close();
  }

  /// Writes the response to the wire and closes the underlying [HttpResponse].
  ///
  /// Callers must await this: the returned future completes once the
  /// response has been flushed and the connection closed.
  Future<void> makeResponse(HttpResponse res) async {
    res.statusCode = httpStatusCode;
    if (headers.isNotEmpty) {
      headers.forEach((key, value) {
        res.headers.set(key, value);
      });
    }
    switch (responseType) {
      case ResponseType.json:
        res.headers.contentType = ContentType.json;
        try {
          final bytes = _jsonUtf8.convert(data);
          res.headers.contentLength = bytes.length;
          res.add(bytes);
        } catch (e) {
          res.write('jsonEncode Error: $e');
        }
        await res.close();
        break;
      case ResponseType.html:
        res.headers.contentType = ContentType.html;
        if (data is String) {
          final bytes = _utf8.convert(data);
          res.headers.contentLength = bytes.length;
          res.add(bytes);
        } else {
          res.write(data);
        }
        await res.close();
        break;
      case ResponseType.sse:
        await sseHandler(res);
        break;
      case ResponseType.streamFile:
        StreamFile? stream = StreamFile(
          fileName: data['fileName'],
          bytes: data['bytes'],
        ).call();
        if (stream == null) {
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({"message": "File not found"}));
          await res.close();
          break;
        }
        res.headers.contentType = stream.contentType;
        res.headers.contentLength = stream.length;
        await res.addStream(stream.stream!);
        await res.close();
        break;
      case ResponseType.download:
        StreamFile? stream = StreamFile(
          fileName: data['fileName'],
          bytes: data['bytes'],
        ).call();
        if (stream == null) {
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({"message": "File not found"}));
          await res.close();
          break;
        }
        res.headers.contentType = stream.contentType;
        res.headers.contentLength = stream.length;
        res.headers.add("Content-Disposition", stream.contentDisposition);
        await res.addStream(stream.stream!);
        await res.close();
        break;
      case ResponseType.redirect:
        res.headers.set(HttpHeaders.locationHeader, data);
        await res.close();
        break;
      case ResponseType.none:
        res.write(data);
        await res.close();
        break;
    }
  }

  static Response redirect(String location) => Response(
    responseType: ResponseType.redirect,
    data: location,
    httpStatusCode: HttpStatus.found,
  );

  static Response json(dynamic jsonData, [int statusCode = HttpStatus.ok]) =>
      Response(
        data: jsonData,
        responseType: ResponseType.json,
        httpStatusCode: statusCode,
      );

  static Response jsonWithHeader(
    dynamic jsonData, {
    int statusCode = HttpStatus.ok,
    Map<String, String> headers = const {},
  }) => Response(
    data: jsonData,
    responseType: ResponseType.json,
    httpStatusCode: statusCode,
    headers: headers,
  );

  /// [statusCode] defaults to 200.
  static Response html(
    dynamic htmlData, {
    int statusCode = HttpStatus.ok,
    Map<String, String> headers = const {},
  }) => Response(
    data: htmlData,
    responseType: ResponseType.html,
    httpStatusCode: statusCode,
    headers: headers,
  );

  static Response file(
    String fileName,
    Uint8List bytes, {
    Map<String, String> headers = const {},
  }) => Response(
    data: {"fileName": fileName, "bytes": bytes},
    responseType: ResponseType.streamFile,
    headers: headers,
  );

  static Response sse(
    Stream<dynamic> eventStream, {
    int statusCode = HttpStatus.ok,
    Map<String, String> headers = const {},
  }) => Response(
    data: eventStream,
    responseType: ResponseType.sse,
    httpStatusCode: statusCode,
    headers: headers,
  );

  static Response download(
    String fileName,
    Uint8List bytes, {
    Map<String, String> headers = const {},
  }) => Response(
    data: {"fileName": fileName, "bytes": bytes},
    responseType: ResponseType.download,
    headers: headers,
  );

  static Response back([String? key, String? message]) {
    String previousRoute = RouteHistory().previousRoute;
    if (key != null && message != null) {
      FlashMessages().flash(key, message);
    }
    if (previousRoute.isNotEmpty) {
      return Response(
        responseType: ResponseType.redirect,
        data: previousRoute,
        httpStatusCode: HttpStatus.found,
      );
    }
    return Response(
      responseType: ResponseType.redirect,
      data: RouteHistory().currentRoute,
      httpStatusCode: HttpStatus.found,
    );
  }

  static Response backWithInput([String? input, String? message]) {
    String previousRoute = RouteHistory().previousRoute;
    if (input != null && message != null) {
      FlashMessages().addError(input, message);
    }
    if (previousRoute.isNotEmpty) {
      return Response(
        responseType: ResponseType.redirect,
        data: previousRoute,
        httpStatusCode: HttpStatus.found,
      );
    }
    return Response(
      responseType: ResponseType.redirect,
      data: RouteHistory().currentRoute,
      httpStatusCode: HttpStatus.found,
    );
  }
}
