import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/config/config.dart';
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

/// Counts the requests that reach it.
class _Records extends Middleware {
  static int runs = 0;

  @override
  Future<void> handle(Request req) async => runs++;
}

/// CSRF protection with `CSRF_PROTECTION_ENABLED`: every method that
/// changes state is checked, and only those.
void main() {
  late Directory sandbox;
  late HttpServer server;
  late HttpClient client;
  final sessions = SessionManager();

  setUpAll(() async {
    Env().load(file: File('test/.env'));
    // Read once, on first use, so it is set before any request.
    Env().env['CSRF_PROTECTION_ENABLED'] = 'true';
    resetSessionGate();
    IoCContainer().register<SessionManager>(
      SessionManager.new,
      singleton: true,
    );
    sandbox = Directory.systemTemp.createTempSync('vania_csrf');
    SessionFileStore()
      ..sessionPath = sandbox.path
      ..invalidateCache();

    clearRouteCaches();
    Router.basePrefix(null);
    Router.get('/form', () => Response.json({}));
    Router.any('/posts/{id}', (int id) => Response.json({'id': id}));
    Router.post('/webhooks/stripe', () => Response.json({}));
    Router.post('/webhooks-admin/purge', () => Response.json({}));
    Router.post('/billing/hooks/paid', () => Response.json({}));
    Config().setApplicationConfig = {
      'csrf_except': ['webhooks', 'billing.hooks/*'],
    };
    Router.post('/recorded', () => Response.json({})).middleware([_Records()]);
    initializeRoutes();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(RequestHandler().handle);
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.close(force: true);
    clearRouteCaches();
    Env().env.remove('CSRF_PROTECTION_ENABLED');
    resetSessionGate();
    SessionFileStore()
      ..sessionPath = 'storage/framework/sessions'
      ..invalidateCache();
    sandbox.deleteSync(recursive: true);
  });

  /// A browser that has loaded a page: its cookies, and the token the
  /// page would have embedded in its forms.
  Future<(List<Cookie>, String)> openPage() async {
    final rq = await client.get('127.0.0.1', server.port, '/form');
    rq.headers.set('accept', 'text/html');
    final res = await rq.close();
    await res.drain<void>();
    final sessionId = res.cookies
        .firstWhere((c) => c.name == sessions.sessionKey)
        .value;
    final stored = await SessionFileStore().retrieveSession(sessionId);
    return (
      [for (final c in res.cookies) Cookie(c.name, c.value)],
      stored!['x_csrf_token'] as String,
    );
  }

  Future<int> send(
    String method, {
    List<Cookie> cookies = const [],
    String? token,
  }) async {
    final rq = await client.open(method, '127.0.0.1', server.port, '/posts/1');
    rq.headers.set('accept', 'application/json');
    rq.cookies.addAll(cookies);
    if (token != null) rq.headers.set('X-CSRF-TOKEN', token);
    if (method == 'QUERY') {
      rq.headers.contentType = ContentType.json;
      rq.write('{}');
    }
    final res = await rq.close();
    await res.drain<void>();
    return res.statusCode;
  }

  const stateChanging = ['POST', 'PUT', 'PATCH', 'DELETE'];

  test('a state-changing request without a token is refused', () async {
    for (final method in stateChanging) {
      expect(await send(method), 419, reason: method);
    }
  });

  test('a state-changing request with a wrong token is refused', () async {
    final (cookies, _) = await openPage();
    for (final method in stateChanging) {
      expect(
        await send(method, cookies: cookies, token: 'forged'),
        419,
        reason: method,
      );
    }
  });

  test('a state-changing request with the page token goes through', () async {
    final (cookies, token) = await openPage();
    for (final method in stateChanging) {
      expect(
        await send(method, cookies: cookies, token: token),
        200,
        reason: method,
      );
    }
  });

  test('a forged request is turned away before the app\'s own middleware '
      'runs', () async {
    _Records.runs = 0;
    final rq = await client.post('127.0.0.1', server.port, '/recorded');
    rq.headers.set('accept', 'application/json');
    final res = await rq.close();
    await res.drain<void>();
    expect(res.statusCode, 419);
    expect(_Records.runs, 0);
  });

  group('csrf_except', () {
    Future<int> post(String path) async {
      final rq = await client.post('127.0.0.1', server.port, path);
      rq.headers.set('accept', 'application/json');
      final res = await rq.close();
      await res.drain<void>();
      return res.statusCode;
    }

    test('a listed path, and the paths under it, are left out', () async {
      expect(await post('/webhooks/stripe'), 200);
    });

    test('a path that only starts with the same letters is not', () async {
      expect(await post('/webhooks-admin/purge'), 419);
    });

    test('a dot in a pattern is a dot, not any character', () async {
      expect(await post('/billing/hooks/paid'), 419);
    });
  });

  test('a safe request needs no token', () async {
    for (final method in ['GET', 'QUERY']) {
      expect(await send(method), 200, reason: method);
    }
  });
}
