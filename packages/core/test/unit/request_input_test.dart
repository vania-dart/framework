import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/route/route_data.dart';

/// Spins up an HTTP server that answers the first request with an empty
/// 200 response so the client can close cleanly, and returns the wrapped
/// [Request] snapshot for assertions.
Future<Request> _makeRequest({
  String cookieHeader = '',
  String query = '',
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final captured = Completer<Request>();

  server.listen((httpReq) async {
    final wrapped = Request().from(
      request: httpReq,
      route: RouteData(method: 'get', path: '/x', action: () {}),
    );
    await wrapped.extractBody();
    // Answer the client so it can close cleanly.
    httpReq.response.statusCode = 200;
    await httpReq.response.close();
    if (!captured.isCompleted) captured.complete(wrapped);
  });

  final client = HttpClient();
  final req = await client.get('127.0.0.1', server.port, '/x?$query');
  if (cookieHeader.isNotEmpty) {
    req.headers.add(HttpHeaders.cookieHeader, cookieHeader);
  }
  final response = await req.close();
  await response.drain();
  client.close(force: true);

  final result = await captured.future;
  await server.close(force: true);
  return result;
}

void main() {
  group('Request._extractCookies', () {
    test(
      'when cookie header contains a value with an equals sign, retains the full value',
      () async {
        final req = await _makeRequest(cookieHeader: 'SESSION=abc=def=ghi');
        expect(req.cookie<String>('SESSION'), equals('abc=def=ghi'));
      },
    );

    test(
      'when cookie header is malformed (no equals sign) does not throw',
      () async {
        final req = await _makeRequest(cookieHeader: 'malformed');
        expect(req.cookie<String>('malformed'), isNull);
      },
    );

    test(
      'when cookie header has multiple pairs separated by semicolons parses each',
      () async {
        final req = await _makeRequest(cookieHeader: 'a=1; b=two; c=three');
        expect(req.cookie<String>('a'), equals('1'));
        expect(req.cookie<String>('b'), equals('two'));
        expect(req.cookie<String>('c'), equals('three'));
      },
    );
  });

  group('Request.input', () {
    test(
      'when value looks like an int with leading zero returns the string verbatim',
      () async {
        final req = await _makeRequest(query: 'code=007');
        expect(req.input('code'), equals('007'));
        expect(req.input('code'), isA<String>());
      },
    );

    test(
      'when value is numeric with no leading zero still returns raw string',
      () async {
        final req = await _makeRequest(query: 'n=42');
        expect(req.input('n'), equals('42'));
        expect(req.input('n'), isA<String>());
      },
    );

    test('when key missing and no default returns null', () async {
      final req = await _makeRequest();
      expect(req.input('nope'), isNull);
    });

    test('when key missing and default provided returns default', () async {
      final req = await _makeRequest();
      expect(req.input('nope', 'fallback'), equals('fallback'));
    });
  });

  group('Request.integer (C6 counterpart)', () {
    test('when value is numeric returns parsed int', () async {
      final req = await _makeRequest(query: 'n=42');
      expect(req.integer('n'), equals(42));
    });

    test(
      'when value has leading zero, integer() still parses to int',
      () async {
        final req = await _makeRequest(query: 'code=007');
        expect(req.integer('code'), equals(7));
      },
    );
  });
}
