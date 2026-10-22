import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';
import 'package:vania/src/route/set_static_path.dart';

/// HEAD asks for exactly what GET would answer, minus the body (RFC 9110
/// §9.3.2). Health checks and link checkers rely on it.
void main() {
  late Directory sandbox;
  late HttpServer server;
  late HttpClient client;
  var getRuns = 0;

  setUpAll(() async {
    sandbox = Directory.systemTemp.createTempSync('vania_head');
    Directory('${sandbox.path}/public').createSync();
    File('${sandbox.path}/public/app.css').writeAsStringSync('body{}' * 10);
    File('${sandbox.path}/video.mp4').writeAsBytesSync(List.filled(500, 1));
    staticPublicRoot = '${sandbox.path}/public';

    clearRouteCaches();
    Router.basePrefix(null);
    Router.get('/status', () {
      getRuns++;
      return Response.json({'status': 'ok'});
    });
    Router.post('/only-post', () => Response.json({}));
    Router.get('/video', () => Response.fromPath('${sandbox.path}/video.mp4'));
    initializeRoutes();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(RequestHandler().handle);
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.close(force: true);
    clearRouteCaches();
    staticPublicRoot = 'public';
    sandbox.deleteSync(recursive: true);
  });

  Future<(HttpClientResponse, List<int>)> send(
    String method,
    String path,
  ) async {
    final rq = await client.open(method, '127.0.0.1', server.port, path);
    rq.headers.set('accept', 'application/json');
    final res = await rq.close();
    return (res, await res.fold<List<int>>([], (a, b) => a..addAll(b)));
  }

  test('HEAD on a GET route answers as GET would, without the body', () async {
    final (get, getBody) = await send('GET', '/status');
    final runsAfterGet = getRuns;
    final (head, headBody) = await send('HEAD', '/status');

    expect(head.statusCode, 200);
    expect(headBody, isEmpty);
    expect(head.headers.contentLength, getBody.length);
    expect(
      head.headers.contentType?.mimeType,
      get.headers.contentType?.mimeType,
    );
    expect(getRuns, runsAfterGet + 1, reason: 'the GET action answers it');
  });

  test('HEAD on a static file sends its headers, not the file', () async {
    final (res, body) = await send('HEAD', '/app.css');
    expect(res.statusCode, 200);
    expect(body, isEmpty);
    expect(res.headers.contentLength, 60);
    expect(res.headers.value('etag'), isNotNull);
  });

  test('HEAD on a file response sends its headers, not the file', () async {
    final (res, body) = await send('HEAD', '/video');
    expect(res.statusCode, 200);
    expect(body, isEmpty);
    expect(res.headers.contentLength, 500);
    expect(res.headers.value('accept-ranges'), 'bytes');
  });

  test('HEAD on a path with no GET route is still a 404', () async {
    expect((await send('HEAD', '/only-post')).$1.statusCode, 404);
    expect((await send('HEAD', '/nowhere')).$1.statusCode, 404);
  });

  test('OPTIONS lists HEAD wherever GET is allowed', () async {
    final (res, _) = await send('OPTIONS', '/status');
    expect(res.headers.value('allow'), 'GET, HEAD, OPTIONS');
  });
}
