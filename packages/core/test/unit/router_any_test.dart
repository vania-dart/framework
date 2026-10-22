import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/enum/http_request_method.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

class _DenyAll extends Middleware {
  @override
  Future<void> handle(Request req) async =>
      throw Unauthenticated(message: 'denied');
}

/// `Router.any` registers one route per method; whatever is chained after
/// it must apply to every one of them, not only the last.
void main() {
  late HttpServer server;
  late HttpClient client;

  setUpAll(() async {
    clearRouteCaches();
    Router.basePrefix(null);
    Router.any(
      '/guarded',
      () => Response.json({'secret': 42}),
    ).middleware([_DenyAll()]);
    Router.any(
      '/items/{id}',
      (int id) => Response.json({'id': id}),
    ).whereInt('id').name('items.any');
    Router.group(() {
      Router.any('/panel', () => Response.json({'panel': true}));
    }, prefix: 'admin');
    initializeRoutes();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(RequestHandler().handle);
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.close(force: true);
    clearRouteCaches();
  });

  Future<int> send(String method, String path) async {
    final rq = await client.open(method, '127.0.0.1', server.port, path);
    rq.headers.set('accept', 'application/json');
    if (method == 'QUERY') {
      rq.headers.contentType = ContentType.json;
      rq.write('{}');
    }
    final res = await rq.close();
    await res.drain<void>();
    return res.statusCode;
  }

  const methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'QUERY'];

  test('middleware chained after any guards every method', () async {
    for (final method in methods) {
      expect(await send(method, '/guarded'), 401, reason: method);
    }
  });

  test('a constraint chained after any applies to every method', () async {
    for (final method in methods) {
      expect(await send(method, '/items/7'), 200, reason: method);
      expect(await send(method, '/items/x'), 404, reason: method);
    }
  });

  test('a name chained after any names every method', () {
    final named = Router().routes.where((r) => r.name == 'items.any');
    expect(
      named.map((r) => r.method).toSet(),
      hasLength(HttpRequestMethod.values.length),
    );
  });

  test('any inside a group takes the group prefix', () async {
    for (final method in methods) {
      expect(await send(method, '/admin/panel'), 200, reason: method);
      expect(await send(method, '/panel'), 404, reason: method);
    }
  });
}
