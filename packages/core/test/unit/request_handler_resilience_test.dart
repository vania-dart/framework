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

  setUp(() async {
    clearRouteCaches();
    Router.basePrefix(null);
    // The controller has already put headers and part of a body on the
    // wire when it fails, so the error response cannot be written.
    Router.get('/fails-mid-response', (Request req) async {
      req.response.write('partial');
      await req.response.flush();
      throw StateError('failed after the response started');
    });
    Router.get('/ok', () => Response.json({'ok': true}));
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
    final res = await rq.close();
    final body = await res.transform(const SystemEncoding().decoder).join();
    return (res.statusCode, body);
  }

  test('a failure after the response started does not take the server '
      'down', () async {
    try {
      await get('/fails-mid-response');
    } on HttpException {
      // The client may see a truncated response; that is acceptable.
    }

    final (status, body) = await get('/ok');
    expect(status, 200);
    expect(body, '{"ok":true}');
  });
}
