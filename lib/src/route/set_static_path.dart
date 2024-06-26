import 'dart:io';

import 'package:vania/src/utils/functions.dart';
import 'package:vania/vania.dart';
import 'package:path/path.dart' as path;

bool? setStaticPath(HttpRequest req) {
  String routePath = Uri.decodeComponent(req.uri.path);
  if (!routePath.endsWith("/")) {
    File file = File(sanitizeRoutePath("public/$routePath"));
    if (file.existsSync()) {
      Response response = Response.file(
        path.basename(file.path),
        file.readAsBytesSync(),
      );
      response.makeResponse(req.response);
      return true;
    } else {
      return null;
    }
  } else {
    return null;
  }
}
