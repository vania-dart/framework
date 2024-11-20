import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:vaniaFramework/src/http/response/stream_file.dart';

enum ResponseType {
  json,
  none,
  html,
  sse,
  streamFile,
  download,
}

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

  void makeResponse(HttpResponse res) async {
    res.statusCode = httpStatusCode;
    if (headers.isNotEmpty) {
      headers.forEach((key, value) {
        res.headers.add(key, value);
      });
    }
    switch (responseType) {
      case ResponseType.json:
        res.headers.contentType = ContentType.json;
        try {
          res.write(jsonEncode(data));
        } catch (_) {
          res.write(jsonEncode(data.toString()));
        }
        await res.close();
        break;
      case ResponseType.html:
        res.headers.contentType = ContentType.html;
        res.write(data);
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
        res.addStream(stream.stream!).then((_) => res.close());
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
        res.addStream(stream.stream!).then((_) => res.close());
        break;
      default:
        res.write(data);
        await res.close();
    }
  }

  static json(
    dynamic jsonData, [
    int statusCode = HttpStatus.ok,
  ]) =>
      Response(
        data: jsonData,
        responseType: ResponseType.json,
        httpStatusCode: statusCode,
      );

  static jsonWithHeader(
    dynamic jsonData, {
    int statusCode = HttpStatus.ok,
    Map<String, String> headers = const {},
  }) =>
      Response(
        data: jsonData,
        responseType: ResponseType.json,
        httpStatusCode: statusCode,
        headers: headers,
      );

  static html(
    dynamic htmlData, {
    Map<String, String> headers = const {},
  }) =>
      Response(
        data: htmlData,
        responseType: ResponseType.html,
        headers: headers,
      );

  static file(
    String fileName,
    Uint8List bytes, {
    Map<String, String> headers = const {},
  }) =>
      Response(
        data: {
          "fileName": fileName,
          "bytes": bytes,
        },
        responseType: ResponseType.streamFile,
        headers: headers,
      );

  static sse(
    Stream<dynamic> eventStream, {
    int statusCode = HttpStatus.ok,
    Map<String, String> headers = const {},
  }) =>
      Response(
        data: eventStream,
        responseType: ResponseType.sse,
        httpStatusCode: statusCode,
        headers: headers,
      );

  static download(
    String fileName,
    Uint8List bytes, {
    Map<String, String> headers = const {},
  }) =>
      Response(
        data: {
          "fileName": fileName,
          "bytes": bytes,
        },
        responseType: ResponseType.download,
        headers: headers,
      );
}
