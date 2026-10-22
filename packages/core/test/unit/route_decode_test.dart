import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

/// A path arrives percent-encoded; routes and their parameters are text.
void main() {
  late HttpServer server;
  late HttpClient client;

  setUpAll(() async {
    clearRouteCaches();
    Router.basePrefix(null);
    Router.get(
      '/posts/{slug}',
      (String slug) => Response.json(slug),
    ).whereString('slug');
    Router.get('/مقالات/{id}', (int id) => Response.json(id)).whereInt('id');
    Router.get('/درباره-ما', () => Response.json('about'));
    Router.get(
      '/files/{name}',
      (String name) => Response.json(name),
    ).whereString('name');
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

  /// Sends [rawPath] exactly as written, percent-encoding and all.
  Future<(int, Object?)> get(String rawPath) async {
    final socket = await Socket.connect('127.0.0.1', server.port);
    socket.write(
      'GET $rawPath HTTP/1.1\r\nHost: x\r\nAccept: application/json\r\n'
      'Connection: close\r\n\r\n',
    );
    final raw = utf8.decode(await socket.expand((c) => c).toList());
    socket.destroy();
    final status = int.parse(raw.split(' ')[1]);
    final body = raw.substring(raw.indexOf('\r\n\r\n') + 4);
    return (status, body.isEmpty ? null : jsonDecode(body));
  }

  String encode(String path) =>
      path.split('/').map(Uri.encodeComponent).join('/');

  test('a parameter reaches the controller decoded', () async {
    expect(await get('/posts/${Uri.encodeComponent('سلام دنیا')}'), (
      200,
      'سلام دنیا',
    ));
    expect(await get('/posts/hello%20world'), (200, 'hello world'));
  });

  test('a route written in Persian matches its encoded request', () async {
    expect(await get(encode('/مقالات/7')), (200, 7));
    expect(await get(encode('/درباره-ما')), (200, 'about'));
  });

  test('an encoded slash stays inside its parameter', () async {
    expect(await get('/files/a%2Fb.txt'), (200, 'a/b.txt'));
  });

  test('a plus sign in a path is a plus sign', () async {
    expect(await get('/posts/c++'), (200, 'c++'));
  });

  test('a malformed escape is a 404, not a 500', () async {
    expect((await get('/posts/%E0%A4%A')).$1, 404);
  });
}
