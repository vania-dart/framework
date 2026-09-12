import 'dart:io';

import 'package:vania/src/http/request/request.dart';

/// Continues the middleware chain. Returns once every remaining
/// middleware and the controller have finished.
typedef Next = Future<void> Function();

/// Runs before a route's controller.
///
/// There are two ways to write one.
///
/// **Override [handle]** when the middleware only inspects or augments
/// the request, and rejects by throwing. This is the common case:
///
/// ```dart
/// class RequireApiKey extends Middleware {
///   @override
///   Future<void> handle(Request req) async {
///     if (req.header('x-api-key') != expected) {
///       throw Unauthenticated(message: 'Bad key');
///     }
///   }
/// }
/// ```
///
/// **Override [process]** when the middleware needs to do something
/// *after* the rest of the chain runs — timing, logging, adding a header
/// that depends on the response — or to skip the chain entirely:
///
/// ```dart
/// class Timing extends Middleware {
///   @override
///   Future<void> process(Request req, Next next) async {
///     final started = DateTime.now();
///     await next();
///     final ms = DateTime.now().difference(started).inMilliseconds;
///     req.response.headers.add('X-Duration-Ms', '$ms');
///   }
/// }
/// ```
///
/// Not calling `next()` stops the chain: no later middleware runs and the
/// controller is not invoked. The middleware is then responsible for the
/// response.
///
/// Overriding both is a mistake — [process] wins and [handle] is ignored.
abstract class Middleware {
  /// Inspect or reject the request. Throw to abort the chain.
  ///
  /// The default implementation does nothing, so a middleware that only
  /// overrides [process] does not need to define it.
  Future<void> handle(Request req) async {}

  /// Wraps the rest of the chain.
  ///
  /// The default implementation calls [handle] and then continues, which
  /// is what makes [handle]-only middleware work unchanged.
  Future<void> process(Request req, Next next) async {
    await handle(req);
    await next();
  }
}

abstract class WebSocketMiddleware {
  Future handle(HttpRequest req);
}
