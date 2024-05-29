import 'dart:io';

import 'package:vania/src/utils/functions.dart';
import 'package:vania/vania.dart';

Future<bool?> setStaticPath(HttpRequest req) {
  String path = Uri.decodeComponent(req.uri.path);
  if (!path.endsWith("/")) {
    File file = File(sanitizeRoutePath("public/$path"));
    if (file.existsSync()) {
      Response response = Response.file(file.path);
      response.makeResponse(req.response);
      return Future.value(true);
    } else {
      return Future.value(null);
    }
  } else {
    return Future.value(null);
  }
}
