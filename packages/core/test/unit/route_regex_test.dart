import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

class _Items {
  Response index() => Response.json('index');
  Response create() => Response.json('create');
  Response store() => Response.json('store');
  Response show(dynamic id) => Response.json('show $id');
  Response edit(dynamic id) => Response.json('edit $id');
  Response update(dynamic id) => Response.json('update $id');
  Response destroy(dynamic id) => Response.json('destroy $id');
}

/// A `where` pattern has to match the whole segment, as the routing docs
/// promise: "reject non-matching requests".
void main() {
  late HttpServer server;
  late HttpClient client;

  setUpAll(() async {
    clearRouteCaches();
    Router.basePrefix(null);
    Router.get(
      '/num/{id}',
      (dynamic id) => Response.json(id),
    ).where('id', r'\d+');
    Router.get(
      '/slug/{slug}',
      (dynamic slug) => Response.json(slug),
    ).where('slug', r'[a-z0-9-]+');
    Router.get(
      '/anchored/{code}',
      (dynamic code) => Response.json(code),
    ).where('code', r'^[A-Z]{3}$');
    Router.resource('/items', _Items());
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

  Future<int> get(String path) async {
    final rq = await client.get('127.0.0.1', server.port, path);
    rq.headers.set('accept', 'application/json');
    final res = await rq.close();
    await res.drain<void>();
    return res.statusCode;
  }

  test('a value that only contains a match is not a match', () async {
    expect(await get('/num/123'), 200);
    expect(await get('/num/abc123'), 404);
    expect(await get('/num/123abc'), 404);
  });

  test('a character class has to cover the whole segment', () async {
    expect(await get('/slug/hello-world-2'), 200);
    expect(await get('/slug/Hello!'), 404);
  });

  test('a pattern that anchors itself still works', () async {
    expect(await get('/anchored/ABC'), 200);
    expect(await get('/anchored/ABCD'), 404);
  });

  test('a resource id takes digits, with an optional decimal part, and '
      'nothing else', () async {
    expect(await get('/items/12'), 200);
    expect(await get('/items/12.5'), 200);
    expect(await get('/items/12a5'), 404);
    expect(await get('/items/x12'), 404);
  });
}
