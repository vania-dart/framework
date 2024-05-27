import 'dart:io';

import 'package:vania/vania.dart';

abstract class Middleware {
  Future handle(Request req);
  Middleware? next;

  void setNext(Middleware middleware) {
    next = middleware;
  }
}

abstract class WebSocketMiddleware {
  Future handle(HttpRequest req);
  WebSocketMiddleware? next;

  void setNext(WebSocketMiddleware middleware) {
    next = middleware;
  }
}
