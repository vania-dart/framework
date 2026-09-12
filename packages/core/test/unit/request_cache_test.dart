import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/route/route_data.dart';

Future<Request> _makeRequest({String query = ''}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final captured = Completer<Request>();

  server.listen((httpReq) async {
    final wrapped = Request().from(
      request: httpReq,
      route: RouteData(method: 'get', path: '/x', action: () {}),
    );
    await wrapped.extractBody();
    httpReq.response.statusCode = 200;
    await httpReq.response.close();
    if (!captured.isCompleted) captured.complete(wrapped);
  });

  final client = HttpClient();
  final req = await client.get('127.0.0.1', server.port, '/x?$query');
  final resp = await req.close();
  await resp.drain<void>();
  client.close(force: true);
  final result = await captured.future;
  await server.close(force: true);
  return result;
}

void main() {
  group('Request.all() caching', () {
    test(
      'all() returns identical map contents across repeated calls',
      () async {
        final req = await _makeRequest(query: 'a=1&b=2');
        final first = req.all();
        final second = req.all();
        expect(first, equals(second));
      },
    );

    test(
      'all() returned map cannot be mutated by caller (unmodifiable)',
      () async {
        final req = await _makeRequest(query: 'a=1');
        final map = req.all();
        expect(() => map['x'] = 'y', throwsUnsupportedError);
      },
    );
  });

  group('Request.merge()', () {
    test(
      'merge() adds values that later show up in input() and all()',
      () async {
        final req = await _makeRequest(query: 'a=1');
        req.merge({'age': 30});
        expect(req.input('age'), equals(30));
        expect(req.all()['age'], equals(30));
      },
    );

    test('merge() overwrites existing values', () async {
      final req = await _makeRequest(query: 'a=1');
      req.merge({'a': 99});
      expect(req.input('a'), equals(99));
    });

    test(
      'merge() preserves existing values not touched by the merge',
      () async {
        final req = await _makeRequest(query: 'a=1&b=2');
        req.merge({'c': 3});
        expect(req.all(), containsPair('a', '1'));
        expect(req.all(), containsPair('b', '2'));
        expect(req.all(), containsPair('c', 3));
      },
    );
  });
}
