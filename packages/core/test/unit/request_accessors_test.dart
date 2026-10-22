import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/route/route_data.dart';

/// POSTs [body] and hands [inspect] the server's [Request] with its body
/// already read.
Future<void> _withBody(
  String contentType,
  String body,
  Future<void> Function(Request req) inspect,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final done = Completer<void>();
  server.listen((httpReq) async {
    try {
      final req = Request().from(
        request: httpReq,
        route: RouteData(method: 'post', path: '/x', action: () {}),
      );
      await req.extractBody();
      await inspect(req);
      done.complete();
    } catch (e, s) {
      done.completeError(e, s);
    }
    await httpReq.response.close();
  });

  final client = HttpClient();
  final rq = await client.post('127.0.0.1', server.port, '/x');
  rq.headers.set('content-type', contentType);
  rq.add(utf8.encode(body));
  await (await rq.close()).drain<void>();
  client.close(force: true);
  try {
    await done.future;
  } finally {
    await server.close(force: true);
  }
}

void main() {
  test('has() is true for a present non-string value', () {
    return _withBody('application/json', '{"age":30,"name":""}', (r) async {
      expect(r.has('age'), isTrue);
      expect(r.has('name'), isFalse);
      expect(r.has('missing'), isFalse);
    });
  });

  test('except() leaves the request input alone', () {
    return _withBody('application/json', '{"user":"a","pass":"b"}', (r) async {
      expect(r.except('pass'), {'user': 'a'});
      expect(r.except(['user', 'pass']), isEmpty);
      expect(r.input('pass'), 'b');
      expect(r.all(), {'user': 'a', 'pass': 'b'});
    });
  });

  test('headers keeps values sent on separate lines apart', () async {
    // HttpClient folds repeated headers onto one line, so this is sent raw.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final seen = Completer<Object?>();
    server.listen((httpReq) async {
      seen.complete(Request().from(request: httpReq).headers['x-multi']);
      await httpReq.response.close();
    });
    final socket = await Socket.connect('127.0.0.1', server.port);
    socket.write(
      'GET / HTTP/1.1\r\nHost: x\r\nX-Multi: a\r\nX-Multi: b\r\n'
      'Connection: close\r\n\r\n',
    );
    expect(await seen.future, 'a, b');
    socket.destroy();
    await server.close(force: true);
  });

  test('file() and files() on a text field are null, not a crash', () {
    const body =
        '--XyZ\r\n'
        'Content-Disposition: form-data; name="avatar"\r\n\r\n'
        'not a file\r\n'
        '--XyZ--\r\n';
    return _withBody('multipart/form-data; boundary=XyZ', body, (r) async {
      expect(r.file('avatar'), isNull);
      expect(r.files('avatar'), isNull);
      expect(r.hasFile('avatar'), isFalse);
    });
  });

  test('file() and files() still return uploads', () {
    const body =
        '--XyZ\r\n'
        'Content-Disposition: form-data; name="docs[]"; filename="a.txt"\r\n'
        'Content-Type: text/plain\r\n\r\n'
        'one\r\n'
        '--XyZ\r\n'
        'Content-Disposition: form-data; name="docs[]"; filename="b.txt"\r\n'
        'Content-Type: text/plain\r\n\r\n'
        'two\r\n'
        '--XyZ--\r\n';
    return _withBody('multipart/form-data; boundary=XyZ', body, (r) async {
      expect(r.file('docs')!.filename, 'a.txt');
      expect(r.files('docs')!.map((f) => f.filename), ['a.txt', 'b.txt']);
      expect(r.hasFile('docs'), isTrue);
    });
  });
}
