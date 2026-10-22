import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

void main() {
  late HttpServer server;
  late HttpClient client;

  setUpAll(() async {
    clearRouteCaches();
    Router.basePrefix(null);
    Router.get('/empty', () => Response());
    Router.get('/back', () => Response.back());
    Router.get('/slug/{s}', (String s) => Response.json([s])).whereString('s');
    Router.get('/num/{x}', (double x) => Response.json([x])).whereDouble('x');
    Router.get('/flag/{b}', (bool b) => Response.json([b])).whereBool('b');
    Router.get('/count/{n}', (int n) => Response.json([n])).whereInt('n');
    Router.get('/validate', (Request req) async {
      await req.validate({'name': 'required'});
      return Response.json({'ok': true});
    });
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

  Future<(HttpClientResponse, String)> get(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final rq = await client.get('127.0.0.1', server.port, path);
    rq.followRedirects = false;
    headers.forEach(rq.headers.set);
    final res = await rq.close();
    return (res, await res.transform(systemEncoding.decoder).join());
  }

  test('a response with no data has an empty body, not "null"', () async {
    final (res, body) = await get('/empty');
    expect(res.statusCode, 200);
    expect(body, isEmpty);
  });

  group('Response.back()', () {
    test('goes to a same-origin Referer', () async {
      final (res, _) = await get(
        '/back',
        headers: {'referer': 'http://127.0.0.1:${server.port}/form?step=2'},
      );
      expect(res.statusCode, 302);
      expect(res.headers.value('location'), '/form?step=2');
    });

    test('ignores a Referer from another site', () async {
      final (res, _) = await get(
        '/back',
        headers: {'referer': 'https://evil.example/phish'},
      );
      expect(res.headers.value('location'), '/');
    });

    test('with nothing to go back to, goes to /', () async {
      final (res, _) = await get('/back');
      expect(res.headers.value('location'), '/');
    });
  });

  group('declared parameter types reach the controller as declared', () {
    test('whereString keeps digits a String', () async {
      expect((await get('/slug/2024')).$2, '["2024"]');
    });

    test('whereDouble passes a double, and rejects a non-number', () async {
      expect((await get('/num/5')).$2, '[5.0]');
      expect((await get('/num/abc')).$1.statusCode, 404);
    });

    test('whereBool passes a bool, and rejects anything else', () async {
      expect((await get('/flag/TRUE')).$2, '[true]');
      expect((await get('/flag/yes')).$1.statusCode, 404);
    });

    test('whereInt is unchanged', () async {
      expect((await get('/count/7')).$2, '[7]');
      expect((await get('/count/x')).$1.statusCode, 404);
    });
  });

  test('a failed validation without sessions answers 422, not a redirect '
      'nowhere', () async {
    // The app has no views, so there is no session to carry the errors
    // across a redirect — even for a browser asking for HTML.
    final (res, _) = await get(
      '/validate',
      headers: {'accept': 'text/html,application/json'},
    );
    expect(res.statusCode, 422);
  });
}
