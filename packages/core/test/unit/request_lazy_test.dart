import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/route/route_data.dart';

/// Hands [inspect] a [Request] for a POST carrying a cookie and a JSON
/// body, before its body has been read — where middleware sees it.
Future<void> _withRequest(Future<void> Function(Request req) inspect) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final done = Completer<void>();
  server.listen((httpReq) async {
    try {
      await inspect(
        Request().from(
          request: httpReq,
          route: RouteData(method: 'post', path: '/x', action: () {}),
        ),
      );
      done.complete();
    } catch (e, s) {
      done.completeError(e, s);
    }
    await httpReq.response.close();
  });

  final client = HttpClient();
  final rq = await client.post('127.0.0.1', server.port, '/x?q=1');
  rq.headers
    ..set('cookie', 'XSRF-TOKEN=abc=; other=2')
    ..contentType = ContentType.json;
  rq.write('{"name":"vania"}');
  await (await rq.close()).drain<void>();
  client.close(force: true);
  try {
    await done.future;
  } finally {
    await server.close(force: true);
  }
}

void main() {
  test('cookies are readable before the body is, as middleware needs', () {
    // CsrfMiddleware checks the XSRF-TOKEN cookie before it reads the body.
    return _withRequest((req) async {
      expect(req.cookie<String>('XSRF-TOKEN'), 'abc=');
      expect(req.cookie<int>('other'), 2);
    });
  });

  test('input read before the body still sees the body afterwards', () {
    return _withRequest((req) async {
      expect(req.input('q'), '1');
      await req.extractBody();
      expect(req.input('name'), 'vania');
      expect(req.all(), {'name': 'vania', 'q': '1'});
    });
  });
}
