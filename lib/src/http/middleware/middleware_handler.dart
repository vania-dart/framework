import 'package:vania/src/http/request/request.dart';
import 'middleware.dart';

Future<void> middlewareHandler(
    List<Middleware> middlewares, Request request) async {
  for (int i = 0; i < middlewares.length - 1; i++) {
    middlewares[i].setNext(middlewares[i + 1]);
  }
  await middlewares.first.handle(request);
}
