import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

/// A controller for an API: no `create` or `edit`, which only serve forms.
class _ApiController {
  Response index() => Response.json('index');
  Response store() => Response.json('store');
  Response show(int id) => Response.json('show $id');
  Response update(int id) => Response.json('update $id');
  Response destroy(int id) => Response.json('destroy $id');
}

class _Tagged extends Middleware {
  @override
  Future<void> handle(Request req) async =>
      req.response.headers.set('x-tagged', 'yes');
}

void main() {
  late HttpServer server;
  late HttpClient client;

  setUpAll(() async {
    clearRouteCaches();
    Router.basePrefix(null);
    Router.apiResource('/photos', _ApiController(), middleware: [_Tagged()]);

    // A group whose callback fails part-way.
    try {
      Router.group(
        () {
          Router.get('/inside', () => Response.json('inside'));
          throw StateError('a route file failed');
        },
        prefix: 'admin',
        middleware: [_Tagged()],
      );
    } on StateError {
      // The app may carry on registering other route files.
    }
    Router.get('/outside', () => Response.json('outside'));
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

  Future<(int, String, String?)> send(String method, String path) async {
    final rq = await client.open(method, '127.0.0.1', server.port, path);
    rq.headers.set('accept', 'application/json');
    final res = await rq.close();
    return (
      res.statusCode,
      await res.transform(systemEncoding.decoder).join(),
      res.headers.value('x-tagged'),
    );
  }

  group('apiResource', () {
    test(
      'registers the five API actions, update under PUT and PATCH',
      () async {
        expect(await send('GET', '/photos'), (200, '"index"', 'yes'));
        expect(await send('POST', '/photos'), (200, '"store"', 'yes'));
        expect(await send('GET', '/photos/3'), (200, '"show 3"', 'yes'));
        expect(await send('PUT', '/photos/3'), (200, '"update 3"', 'yes'));
        expect(await send('PATCH', '/photos/3'), (200, '"update 3"', 'yes'));
        expect(await send('DELETE', '/photos/3'), (200, '"destroy 3"', 'yes'));
      },
    );

    test('has no form pages', () async {
      expect((await send('GET', '/photos/create')).$1, 404);
      expect((await send('GET', '/photos/3/edit')).$1, 404);
    });
  });

  test(
    'a group that fails part-way does not leak its prefix or middleware',
    () async {
      expect(await send('GET', '/outside'), (200, '"outside"', null));
      expect((await send('GET', '/admin/outside')).$1, 404);
    },
  );
}
