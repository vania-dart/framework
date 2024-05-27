import 'dart:io';
import 'middleware.dart';

Future<void> webSocketMiddlewareHandler(
    List<WebSocketMiddleware> middlewares, HttpRequest request) async {
  for (int i = 0; i < middlewares.length - 1; i++) {
    middlewares[i].setNext(middlewares[i + 1]);
  }
  await middlewares.first.handle(request);
}
