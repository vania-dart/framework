import 'package:vania/src/http/request/request.dart';
import 'middleware.dart';

Future<void> middlewareHandler(
  List<Middleware> middlewares,
  Request request,
) async {
  for (Middleware middleware in middlewares) {
    await middleware.handle(request);
  }
}
