import 'package:vania/src/http/request/request.dart';
import 'middleware.dart';

/// Runs [middlewares] in order, then [terminal].
///
/// Each middleware's [Middleware.process] receives a `next` callback that
/// continues into the rest of the chain, so a middleware can do work on
/// either side of it — or skip the remainder by not calling it.
///
/// A middleware that throws aborts the chain; [terminal] does not run.
/// One that calls `next` a second time gets a [StateError]: running the
/// rest of the chain twice would run the controller twice.
Future<void> middlewareHandler(
  List<Middleware> middlewares,
  Request request, [
  Future<void> Function()? terminal,
]) {
  Future<void> run(int index) {
    if (index >= middlewares.length) return terminal?.call() ?? Future.value();
    final middleware = middlewares[index];
    var called = false;
    return middleware.process(request, () {
      if (called) {
        throw StateError(
          '${middleware.runtimeType} called next() more than once.',
        );
      }
      called = true;
      return run(index + 1);
    });
  }

  return run(0);
}
