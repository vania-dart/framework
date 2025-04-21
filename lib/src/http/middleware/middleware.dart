import 'dart:io';

import 'package:vania/src/http/request/request.dart';

abstract class Middleware {
  Future handle(Request req);
}

abstract class WebSocketMiddleware {
  Future handle(HttpRequest req);
}
