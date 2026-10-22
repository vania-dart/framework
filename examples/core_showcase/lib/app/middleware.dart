import 'package:vania/http/middleware.dart';
import 'package:vania/http/request.dart';
import 'package:vania/http/response.dart';
import 'package:vania/vania.dart' show Unauthenticated, getSession;

/// Refuses everything — guards `Router.any`, every method of it.
class DenyAll extends Middleware {
  @override
  Future<void> handle(Request req) async =>
      throw Unauthenticated(message: 'Unauthenticated');
}

/// Adds a header after the controller has run.
class Timing extends Middleware {
  @override
  Future<void> process(Request req, Next next) async {
    final started = DateTime.now();
    await next();
    final ms = DateTime.now().difference(started).inMicroseconds / 1000;
    req.response.headers.add('X-Duration-Ms', ms.toStringAsFixed(2));
  }
}

/// A bug: runs the rest of the chain twice.
class CallsNextTwice extends Middleware {
  @override
  Future<void> process(Request req, Next next) async {
    await next();
    await next();
  }
}

/// A bug: ends the chain without answering.
class Forgets extends Middleware {
  @override
  Future<void> process(Request req, Next next) async {}
}

/// Sees the controller's error on its way out, then lets it through.
class Observes extends Middleware {
  @override
  Future<void> process(Request req, Next next) async {
    try {
      await next();
    } catch (e) {
      req.response.headers.set('X-Observed-Error', e.runtimeType.toString());
      rethrow;
    }
  }
}

/// Throws whatever [error] builds.
class Throws extends Middleware {
  Throws(this.error);
  final Object Function() error;

  @override
  Future<void> handle(Request req) async => throw error();
}

/// A session guard, as vania_auth's: a browser that is not signed in is
/// sent to the login page.
class SessionGuard extends Middleware {
  @override
  Future<void> handle(Request req) async {
    final signedIn = await getSession<bool?>('logged_in') ?? false;
    if (!signedIn) {
      throw Unauthenticated(message: '/login', responseType: ResponseType.html);
    }
  }
}
