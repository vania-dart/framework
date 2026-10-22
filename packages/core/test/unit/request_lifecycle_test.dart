import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/exception/internal_server_error.dart';
import 'package:vania/src/exception/not_found_exception.dart';
import 'package:vania/src/exception/throttle_exception.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/http/session/session_file_store.dart';
import 'package:vania/src/http/session/session_gate.dart';
import 'package:vania/src/http/session/session_manager.dart';
import 'package:vania/src/ioc_container.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

/// Adds a header once the rest of the chain has run — the example the
/// middleware docs give.
class _Timing extends Middleware {
  @override
  Future<void> process(Request req, Next next) async {
    await next();
    req.response.headers.add('X-Duration-Ms', '1');
  }
}

/// Throws whatever [error] builds, as a guard would.
class _Throws extends Middleware {
  _Throws(this.error);
  final Object Function() error;

  @override
  Future<void> handle(Request req) async => throw error();
}

/// Validates the request before the controller, as a form request would.
class _Validates extends Middleware {
  @override
  Future<void> handle(Request req) async {
    await req.extractBody();
    await req.validate({'email': 'required'});
  }
}

/// Sees the controller's error on its way out.
class _Observes extends Middleware {
  static Object? seen;

  @override
  Future<void> process(Request req, Next next) async {
    try {
      await next();
    } catch (e) {
      seen = e;
      rethrow;
    }
  }
}

/// Ends the chain and forgets to answer.
class _Forgets extends Middleware {
  @override
  Future<void> process(Request req, Next next) async {}
}

/// Ends the chain and answers itself.
class _AnswersItself extends Middleware {
  @override
  Future<void> process(Request req, Next next) async {
    req.response
      ..statusCode = 403
      ..write('handled here');
    await req.response.close();
  }
}

void main() {
  late Directory sandbox;
  late HttpServer server;
  late HttpClient client;

  setUpAll(() async {
    Env().load(file: File('test/.env'));
    Env().env['SESSION_ENABLED'] = 'true';
    resetSessionGate();
    IoCContainer().register<SessionManager>(
      SessionManager.new,
      singleton: true,
    );
    sandbox = Directory.systemTemp.createTempSync('vania_lifecycle');
    SessionFileStore()
      ..sessionPath = sandbox.path
      ..invalidateCache();

    clearRouteCaches();
    Router.basePrefix(null);
    Router.get(
      '/timed',
      () => Response.json({'ok': true}),
    ).middleware([_Timing()]);
    // A session guard asks for the browser to be sent to its login page,
    // as vania_auth does; a token guard only says who is not signed in.
    Unauthenticated toLogin() =>
        Unauthenticated(message: '/login', responseType: ResponseType.html);
    Unauthenticated tokenRejected() =>
        Unauthenticated(message: 'Unauthenticated');
    Router.get('/login-ctrl', () => throw toLogin());
    Router.get(
      '/login-mw',
      () => Response.json({}),
    ).middleware([_Throws(toLogin)]);
    Router.get('/token-ctrl', () => throw tokenRejected());
    Router.get(
      '/token-mw',
      () => Response.json({}),
    ).middleware([_Throws(tokenRejected)]);
    Router.get(
      '/missing-ctrl',
      () => throw NotFoundException(message: {'error': 'no such user'}),
    );
    Router.get(
      '/throttled-ctrl',
      () => throw ThrottleException(
        message: 'Slow down',
        code: 429,
        headers: {'Retry-After': '30'},
      ),
    );
    Router.get('/leaky-mw', () => Response.json({})).middleware([
      _Throws(() => InternalServerError(message: 'db password is hunter2')),
    ]);
    Router.get(
      '/validate-mw',
      () => Response.json({}),
    ).middleware([_Validates()]);
    Router.get(
      '/crash-ctrl',
      () => throw StateError('boom'),
    ).middleware([_Observes()]);
    Router.get('/forgets', () => Response.json({})).middleware([_Forgets()]);
    Router.get('/back-get', () => Response.back());
    Router.post('/back-post', () => Response.back());
    Router.get(
      '/answers-itself',
      () => Response.json({}),
    ).middleware([_AnswersItself()]);
    initializeRoutes();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(RequestHandler().handle);
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.close(force: true);
    clearRouteCaches();
    Env().env.remove('SESSION_ENABLED');
    resetSessionGate();
    SessionFileStore()
      ..sessionPath = 'storage/framework/sessions'
      ..invalidateCache();
    sandbox.deleteSync(recursive: true);
  });

  Future<(HttpClientResponse, String)> get(
    String path, {
    bool html = false,
  }) async {
    final rq = await client.get('127.0.0.1', server.port, path);
    rq.followRedirects = false;
    rq.headers
      ..set('accept', html ? 'text/html' : 'application/json')
      ..set('referer', 'http://127.0.0.1:${server.port}/form');
    final res = await rq.close();
    return (res, await res.transform(utf8.decoder).join());
  }

  group('the response is written once the middleware chain is done', () {
    test('so a middleware can add a header after next()', () async {
      final (res, body) = await get('/timed');
      expect(res.statusCode, 200);
      expect(body, '{"ok":true}');
      expect(res.headers.value('x-duration-ms'), '1');
    });

    test('and a middleware sees the controller\'s error', () async {
      _Observes.seen = null;
      final (res, _) = await get('/crash-ctrl');
      expect(res.statusCode, 500);
      expect(_Observes.seen, isA<StateError>());
    });
  });

  group('back() with no usable Referer', () {
    Future<String?> locationOf(String method, String path) async {
      final rq = await client.open(method, '127.0.0.1', server.port, path);
      rq.followRedirects = false;
      rq.headers
        ..set('accept', 'text/html')
        ..set('referer', 'https://evil.example/phish');
      final res = await rq.close();
      await res.drain<void>();
      return res.headers.value('location');
    }

    test('from a GET goes to /, never back to the same URL', () async {
      // Back to /back-get would answer itself with a redirect, forever.
      expect(await locationOf('GET', '/back-get'), '/');
    });

    test('from a form post goes to the page of the same path', () async {
      expect(await locationOf('POST', '/back-post'), '/back-post');
    });
  });

  group('a middleware that stops the chain', () {
    test('and answers keeps its answer', () async {
      final (res, body) = await get('/answers-itself');
      expect(res.statusCode, 403);
      expect(body, 'handled here');
    });

    test('without answering gets a 500, not a request that hangs', () async {
      final (res, _) = await get(
        '/forgets',
      ).timeout(const Duration(seconds: 3));
      expect(res.statusCode, 500);
    });
  });

  group('an error is answered the same wherever it was thrown', () {
    test('Unauthenticated redirects a browser, from controller or '
        'middleware', () async {
      for (final path in ['/login-ctrl', '/login-mw']) {
        final (res, _) = await get(path, html: true);
        expect(res.statusCode, 302, reason: path);
        expect(res.headers.value('location'), '/login', reason: path);
      }
    });

    test('Unauthenticated is a 401 for an API client either way', () async {
      for (final path in ['/login-ctrl', '/login-mw']) {
        expect((await get(path)).$1.statusCode, 401, reason: path);
      }
    });

    test('an Unauthenticated that asks for no redirect is a 401 even for a '
        'browser, never a redirect to its message', () async {
      for (final path in ['/token-ctrl', '/token-mw']) {
        final (res, _) = await get(path, html: true);
        expect(res.statusCode, 401, reason: path);
        expect(res.headers.value('location'), isNull, reason: path);
      }
    });

    test('an error with a map message keeps its status and body', () async {
      final (res, body) = await get('/missing-ctrl');
      expect(res.statusCode, 404);
      expect(jsonDecode(body), {'error': 'no such user'});
    });

    test('a throttle error keeps its Retry-After', () async {
      final (res, _) = await get('/throttled-ctrl');
      expect(res.statusCode, 429);
      expect(res.headers.value('retry-after'), '30');
    });

    test('a 5xx raised on purpose does not show its message', () async {
      final (res, body) = await get('/leaky-mw');
      expect(res.statusCode, 500);
      expect(body, isNot(contains('hunter2')));
    });

    test('a failed validation in middleware sends a browser back, and an '
        'API client a 422', () async {
      final (page, _) = await get('/validate-mw', html: true);
      expect(page.statusCode, 302);
      expect(page.headers.value('location'), '/form');

      final (api, body) = await get('/validate-mw');
      expect(api.statusCode, 422);
      expect(jsonDecode(body), contains('email'));
    });
  });
}
