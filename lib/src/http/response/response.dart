import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:vania/src/http/response/stream_file.dart';

enum ResponseType {
  json,
  none,
  html,
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
