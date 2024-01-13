import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:vania/src/http/response/download_file.dart';

enum ResponseType { json, html, file, download }

class Response {
  final ResponseType responseType;
  final dynamic data;
  final int httpStatusCode;
  const Response(
      [this.data,
      this.responseType = ResponseType.json,
      this.httpStatusCode = HttpStatus.ok]);

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
      case ResponseType.file:
        String? mimeType = lookupMimeType('jsjavad', headerBytes: data);
        String primaryType = mimeType!.split('/').first;
        String subType = mimeType.split('/').last;
        res.headers.contentType = ContentType(primaryType, subType);
        res.add(data);
        await res.close();
        res.close();
        break;
      case ResponseType.download:
        DownloadFile file = data as DownloadFile;
        res.headers.contentType = file.contentType;
        res.headers.contentLength = file.data!.length;
        res.headers.add("Content-Disposition", file.contentDisposition!);
        res.add(file.data!);
        res.close();
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

  static file(dynamic dataFile) => Response(dataFile, ResponseType.file);

  static download(dynamic dataFile) =>
      Response(dataFile, ResponseType.download);
}
