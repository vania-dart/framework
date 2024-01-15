import 'dart:convert';
import 'dart:io';
import 'package:vania/src/http/response/stream_file.dart';

enum ResponseType { json, html, streamFile, download }

class Response {
  final ResponseType responseType;
  final dynamic data;
  final int httpStatusCode;
  const Response([
    this.data,
    this.responseType = ResponseType.json,
    this.httpStatusCode = HttpStatus.ok,
  ]);

  void makeResponse(HttpResponse res) async {
    res.statusCode = httpStatusCode;
    switch (responseType) {
      case ResponseType.json:
        res.headers.contentType = ContentType.json;
        try {
          res.write(jsonEncode(data));
        } catch (_) {
          res.write(jsonEncode(data.toString()));
        }
        res.close();
        break;
      case ResponseType.html:
        res.headers.contentType = ContentType.html;
        res.write(data);
        res.close();
        break;
      case ResponseType.streamFile:
        StreamFile? stream = StreamFile(filename: data).call();
        if (stream == null) {
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({"message": "File not found"}));
          res.close();
          break;
        }
        res.headers.contentType = stream.contentType;
        res.headers.contentLength = stream.length;
        res.addStream(stream.stream!).then((_) => res.close());
        break;
      case ResponseType.download:
        StreamFile? stream = StreamFile(filename: data).call();
        if (stream == null) {
          res.headers.contentType = ContentType.json;
          res.write(jsonEncode({"message": "File not found"}));
          res.close();
          break;
        }
        res.headers.contentType = stream.contentType;
        res.headers.contentLength = stream.length;
        res.headers.add("Content-Disposition", stream.contentDisposition);
        res.addStream(stream.stream!).then((_) => res.close());
        break;
      default:
        res.write(data);
        res.close();
    }
  }

  static json(dynamic jsonData, [int statusCode = HttpStatus.ok]) => Response(
        jsonData,
        ResponseType.json,
        statusCode,
      );

  static html(dynamic htmlData) => Response(htmlData, ResponseType.html);

  static file(String file) => Response(file, ResponseType.streamFile);

  static download(dynamic file) => Response(file, ResponseType.download);
}
