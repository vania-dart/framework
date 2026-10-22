import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

Future<RouteData?> _match(String path) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final found = Completer<RouteData?>();
  server.listen((req) async {
    found.complete(matchRoute(req));
    await req.response.close();
  });
  final client = HttpClient();
  await (await (await client.get(
    '127.0.0.1',
    server.port,
    path,
  )).close()).drain<void>();
  client.close(force: true);
  await server.close(force: true);
  return found.future;
}

void main() {
  setUp(() {
    clearRouteCaches();
    Router.basePrefix(null);
  });
  tearDown(clearRouteCaches);

  // Router keeps every route registered in this file, so each test uses
  // its own last segment to stay out of the others' way.
  group('dynamic route lookup', () {
    test('when two routes match, the one registered first wins', () async {
      Router.get('/{type}/{id}/a1', () {});
      Router.get('/users/{id}/a1', () {});
      initializeRoutes();

      expect((await _match('/users/5/a1'))!.path, '/{type}/{id}/a1');
    });

    test('in the other order, the literal route wins', () async {
      Router.get('/users/{id}/b2', () {});
      Router.get('/{type}/{id}/b2', () {});
      initializeRoutes();

      final route = await _match('/users/5/b2');
      expect(route!.path, '/users/{id}/b2');
      expect(route.params, {'id': '5'});
    });

    test(
      'a first segment no route names falls to the parameter routes',
      () async {
        initializeRoutes();

        final route = await _match('/posts/3/b2');
        expect(route!.path, '/{type}/{id}/b2');
        expect(route.params, {'type': 'posts', 'id': '3'});
      },
    );

    test('no match is null, not an exception', () async {
      Router.get('/users/{id}/c3', () {});
      initializeRoutes();

      expect(await _match('/posts/3/c3'), isNull);
      expect(await _match('/users/3/c3/extra'), isNull);
    });

    test('a match does not carry params into a later match', () async {
      Router.get('/users/{id}/d4', () {});
      initializeRoutes();

      final first = await _match('/users/1/d4');
      first!.params!['id'] = 'tampered';
      expect((await _match('/users/1/d4'))!.params, {'id': '1'});
    });
  });

  group('unmatched requests', () {
    late HttpServer server;
    late HttpClient client;

    setUp(() async {
      Router.get('/known', () => Response.json({'ok': true}));
      initializeRoutes();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(RequestHandler().handle);
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    Future<(int, String)> send(String method, String path) async {
      final rq = await client.open(method, '127.0.0.1', server.port, path);
      rq.headers.set('accept', 'application/json');
      final res = await rq.close();
      return (
        res.statusCode,
        await res.transform(systemEncoding.decoder).join(),
      );
    }

    test('get a JSON 404', () async {
      expect(await send('GET', '/nope'), (404, '{"message":"Not found"}'));
    });

    test('OPTIONS gets an empty 200, as a CORS preflight needs', () async {
      expect(await send('OPTIONS', '/nope'), (200, ''));
    });
  });

  group('controller arguments', () {
    late HttpServer server;
    late HttpClient client;

    setUp(() async {
      Router.get('/args0', () => Response.json([]));
      Router.get('/args1/{a}', (int a) => Response.json([a]));
      Router.get(
        '/args3/{a}/{b}',
        (Request req, int a, String b) => Response.json([req.path, a, b]),
      );
      Router.get(
        '/args5/{a}/{b}/{c}/{d}/{e}',
        (int a, int b, int c, int d, int e) => Response.json([a, b, c, d, e]),
      );
      initializeRoutes();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(RequestHandler().handle);
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    Future<String> get(String path) async {
      final res = await (await client.get(
        '127.0.0.1',
        server.port,
        path,
      )).close();
      return res.transform(systemEncoding.decoder).join();
    }

    test('reach the controller in order, whatever their number', () async {
      expect(await get('/args0'), '[]');
      expect(await get('/args1/7'), '[7]');
      expect(await get('/args3/7/x'), '["/args3/{a}/{b}",7,"x"]');
      expect(await get('/args5/1/2/3/4/5'), '[1,2,3,4,5]');
    });
  });
}
