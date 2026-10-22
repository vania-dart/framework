import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

/// The HTTP QUERY method, RFC 10008: safe and idempotent like GET, with
/// the query carried in the request content like POST.
void main() {
  late HttpServer server;
  late HttpClient client;

  setUpAll(() async {
    clearRouteCaches();
    Router.basePrefix(null);
    Router.get('/contacts', () => Response.json({'via': 'GET'}));
    Router.query(
      '/contacts',
      (Request req) => Response.json({'via': 'QUERY', 'input': req.all()}),
    ).acceptQuery(['application/json', 'application/x-www-form-urlencoded']);
    Router.query(
      '/sql',
      (Request req) => Response.json({'sql': utf8.decode(req.rawBody)}),
    );
    Router.any('/anything', (Request req) => Response.json([req.method]));
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

  Future<(HttpClientResponse, String)> send(
    String method,
    String path, {
    String? contentType,
    String body = '',
  }) async {
    final rq = await client.open(method, '127.0.0.1', server.port, path);
    rq.headers.set('accept', 'application/json');
    if (contentType != null) rq.headers.set('content-type', contentType);
    rq.write(body);
    final res = await rq.close();
    return (res, await res.transform(utf8.decoder).join());
  }

  test('a QUERY route receives its content as input', () async {
    final (res, body) = await send(
      'QUERY',
      '/contacts?page=2',
      contentType: 'application/json',
      body: '{"surname":"Smith","limit":10}',
    );
    expect(res.statusCode, 200);
    expect(jsonDecode(body), {
      'via': 'QUERY',
      'input': {'surname': 'Smith', 'limit': 10, 'page': '2'},
    });
  });

  test('form-encoded content is input too', () async {
    final (_, body) = await send(
      'QUERY',
      '/contacts',
      contentType: 'application/x-www-form-urlencoded',
      body: 'email=%2A%40example.org&limit=10',
    );
    expect(jsonDecode(body)['input'], {
      'email': '*@example.org',
      'limit': '10',
    });
  });

  test('GET and QUERY on the same path reach their own routes', () async {
    expect((await send('GET', '/contacts')).$2, '{"via":"GET"}');
  });

  test('content of a type the framework does not parse is there raw', () async {
    final (res, body) = await send(
      'QUERY',
      '/sql',
      contentType: 'application/sql',
      body: 'SELECT surname, email FROM contacts LIMIT 10',
    );
    expect(res.statusCode, 200);
    expect(jsonDecode(body), {
      'sql': 'SELECT surname, email FROM contacts LIMIT 10',
    });
  });

  group('a QUERY the server cannot read', () {
    test('without a Content-Type is a 400', () async {
      final (res, _) = await send('QUERY', '/sql', body: 'SELECT 1');
      expect(res.statusCode, 400);
    });

    test('whose content contradicts its Content-Type is a 400', () async {
      final (res, _) = await send(
        'QUERY',
        '/contacts',
        contentType: 'application/json',
        body: '{not json',
      );
      expect(res.statusCode, 400);
    });

    test('of a media type the route does not take is a 415 that says '
        'which it does', () async {
      final (res, _) = await send(
        'QUERY',
        '/contacts',
        contentType: 'application/sql',
        body: 'SELECT 1',
      );
      expect(res.statusCode, 415);
      expect(
        res.headers.value('accept-query'),
        'application/json, application/x-www-form-urlencoded',
      );
    });
  });

  test('a successful QUERY advertises what the route accepts', () async {
    final (res, _) = await send(
      'QUERY',
      '/contacts',
      contentType: 'application/json',
      body: '{}',
    );
    expect(
      res.headers.value('accept-query'),
      'application/json, application/x-www-form-urlencoded',
    );
  });

  test('OPTIONS lists the methods of the path, QUERY included', () async {
    final (res, _) = await send('OPTIONS', '/contacts');
    expect(res.statusCode, 200);
    expect(res.headers.value('allow'), 'GET, HEAD, QUERY, OPTIONS');
    expect(
      res.headers.value('accept-query'),
      'application/json, application/x-www-form-urlencoded',
    );
  });

  test('a POST with unreadable JSON is unchanged: empty input', () async {
    Router.post('/legacy', (Request req) => Response.json(req.all()));
    clearRouteCaches();
    initializeRoutes();
    final (res, body) = await send(
      'POST',
      '/legacy',
      contentType: 'application/json',
      body: '{not json',
    );
    expect(res.statusCode, 200);
    expect(body, '{}');
  });

  test('Router.any answers QUERY as well', () async {
    final (_, body) = await send(
      'QUERY',
      '/anything',
      contentType: 'application/json',
      body: '{}',
    );
    expect(body, '["query"]');
  });
}
