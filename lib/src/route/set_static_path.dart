import 'dart:io';

import 'package:vania/src/utils/functions.dart';
import 'package:vania/vania.dart';

Future<bool?> setStaticPath(HttpRequest req) {
  String path = "${Directory.current.path}/public";
  if (!req.uri.path.endsWith("/")) {
    File file = File(sanitizeRoutePath("$path/${req.uri.path}"));
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
