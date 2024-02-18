import 'package:vania/vania.dart';

abstract class Middleware {
  Future handle(Request req);
  Middleware? next;

  void setNext(Middleware middleware) {
    next = middleware;
  }
}
