import 'dart:io';
import 'package:vaniaFramework/vania_framework.dart';

abstract class Middleware {
  Future handle(Request req);

  @Deprecated('Will be deleted in the next versions')
  Middleware? next;
}

abstract class WebSocketMiddleware {
  Future handle(HttpRequest req);

  @Deprecated('Will be deleted in the next versions')
  WebSocketMiddleware? next;
}
