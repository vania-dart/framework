import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

/// Sends a request to a spun-up loopback server and returns the resolved
/// [RouteData] that `httpRouteHandler` picked (or null on 404).
Future<RouteData?> _resolve({
  required String method,
  required String path,
  String? host,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final captured = Completer<RouteData?>();

  server.listen((req) async {
    RouteData? found;
    try {
      found = httpRouteHandler(req);
    } catch (_) {
      found = null;
    }
    req.response.statusCode = found == null ? 404 : 200;
    await req.response.close();
    if (!captured.isCompleted) captured.complete(found);
  });

  final client = HttpClient();
  final req = await client.open(method, '127.0.0.1', server.port, path);
  // `headers.host` keeps the connection's port appended; route domains are
  // matched against the bare Host header, so set it verbatim.
  if (host != null) req.headers.set(HttpHeaders.hostHeader, host);
  final resp = await req.close();
  await resp.drain<void>();
  client.close(force: true);

  final result = await captured.future;
  await server.close(force: true);
  return result;
}

void main() {
  group('Router route matcher', () {
    setUp(() {
      clearRouteCaches();
    });

    test('when a GET static route is registered, resolves to it', () async {
      Router.basePrefix(null);
      Router.get('/hello-static', () {});
      initializeRoutes();

      final route = await _resolve(method: 'GET', path: '/hello-static');
      expect(route, isNotNull);
      expect(route!.method, equals('get'));
    });

    test('when a GET dynamic route is registered, POST lookup for the same '
        'path does not match', () async {
      Router.basePrefix(null);
      Router.get('/items/{id}', (int id) {});
      initializeRoutes();

      final post = await _resolve(method: 'POST', path: '/items/42');
      expect(post, isNull);
    });

    test('when a dynamic GET route matches, params are captured', () async {
      Router.basePrefix(null);
      Router.get('/widgets/{id}', (int id) {}).whereInt('id');
      initializeRoutes();

      final route = await _resolve(method: 'GET', path: '/widgets/7');
      expect(route, isNotNull);
      expect(route!.params?['id'], equals(7));
    });

    test('many routes across GET/POST resolve in roughly linear time '
        '(no cross-method scanning)', () async {
      Router.basePrefix(null);
      for (var i = 0; i < 100; i++) {
        Router.get('/gr-$i/{id}', (int id) {}).whereInt('id');
        Router.post('/gr-$i/{id}', (int id) {}).whereInt('id');
      }
      initializeRoutes();

      final sw = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        await _resolve(method: 'GET', path: '/gr-$i/1');
      }
      sw.stop();
      expect(sw.elapsed.inSeconds, lessThan(5));
    });

    test('a domain-scoped route does not answer for another host once the '
        'hit cache is warm', () async {
      Router.basePrefix(null);
      Router.get('/dashboard', () {}).domain('admin.site.com');
      initializeRoutes();

      final admin = await _resolve(
        method: 'GET',
        path: '/dashboard',
        host: 'admin.site.com',
      );
      expect(admin, isNotNull);

      final other = await _resolve(
        method: 'GET',
        path: '/dashboard',
        host: 'api.site.com',
      );
      expect(other, isNull);
    });
  });
}
