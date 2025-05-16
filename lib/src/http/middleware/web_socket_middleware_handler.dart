import 'dart:io';
import 'middleware.dart';

Future<void> webSocketMiddlewareHandler(
  List<WebSocketMiddleware> middlewares,
  HttpRequest request,
) async {
  for (WebSocketMiddleware middleware in middlewares) {
    await middleware.handle(request);
  }
}
