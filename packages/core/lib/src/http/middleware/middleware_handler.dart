import 'package:vania/src/http/request/request.dart';
import 'middleware.dart';

/// Runs [middlewares] in order, then [terminal].
///
/// Each middleware's [Middleware.process] receives a `next` callback that
/// continues into the rest of the chain, so a middleware can do work on
/// either side of it — or skip the remainder by not calling it.
///
/// A middleware that throws aborts the chain; [terminal] does not run.
Future<void> middlewareHandler(
  List<Middleware> middlewares,
  Request request, [
  Future<void> Function()? terminal,
]) async {
  var index = 0;

  Future<void> next() async {
    if (index >= middlewares.length) {
      if (terminal != null) await terminal();
      return;
    }
    final middleware = middlewares[index++];
    await middleware.process(request, next);
  }

  await next();
}
