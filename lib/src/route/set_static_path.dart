import 'dart:io';

import 'package:vania/src/utils/functions.dart';
import 'package:vania/vania.dart';

Future<bool?> setStaticPath(HttpRequest req) {
  if (!req.uri.path.endsWith("/")) {
    File file = File(sanitizeRoutePath("public/${req.uri.path}"));
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
