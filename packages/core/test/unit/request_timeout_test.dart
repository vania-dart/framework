import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

void main() {
  late HttpServer server;
  late HttpClient client;

  // Read once, on the first request, so it is set before any.
  Env().env['REQUEST_TIMEOUT'] = '1';

  setUp(() async {
    clearRouteCaches();
    Router.basePrefix(null);
    Router.get('/hangs', () async {
      await Future<void>.delayed(const Duration(seconds: 5));
      return Response.json({'late': true});
    });
    Router.get('/quick', () => Response.json({'ok': true}));
    // Answers at once, then streams for longer than REQUEST_TIMEOUT.
    Router.get(
      '/stream',
      () => Response.sse(
        Stream.periodic(const Duration(milliseconds: 400), (i) => i).take(5),
      ),
    );
    initializeRoutes();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(RequestHandler().handle);
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
    clearRouteCaches();
  });

  Future<(int, String)> get(String path) async {
    final rq = await client.get('127.0.0.1', server.port, path);
    rq.headers.set('accept', 'application/json');
    final res = await rq.close();
    return (res.statusCode, await res.transform(systemEncoding.decoder).join());
  }

  test('a request running past REQUEST_TIMEOUT gets a 503', () async {
    final waited = Stopwatch()..start();
    final (status, body) = await get('/hangs');
    expect(status, 503);
    expect(body, '{"message":"Request timed out"}');
    expect(waited.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('a response already streaming is not cut off', () async {
    final rq = await client.get('127.0.0.1', server.port, '/stream');
    final res = await rq.close();
    final body = await res.transform(systemEncoding.decoder).join();
    expect(res.statusCode, 200);
    expect('data:'.allMatches(body).length, 5);
  });

  test('a request inside REQUEST_TIMEOUT is untouched', () async {
    expect(await get('/quick'), (200, '{"ok":true}'));
  });
}
