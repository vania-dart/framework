import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/exception/http_exception.dart';
import 'package:vania/src/http/request/request_body.dart';

/// Starts a loopback HTTP server, sends a POST with the given payload
/// pattern, and returns the server-side `HttpRequest` for the parser to
/// consume. The server responds with 200 so the client can complete cleanly.
Future<HttpRequest> _postWith({
  required List<int> body,
  required String contentType,
  int chunkCount = 1,
  bool declareContentLength = true,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final captured = Completer<HttpRequest>();

  server.listen((req) async {
    // Answer immediately with 200 so the client-side future resolves; the
    // test then consumes the request body via RequestBody.extractBody.
    if (!captured.isCompleted) captured.complete(req);
  });

  final client = HttpClient();
  final req = await client.post('127.0.0.1', server.port, '/');
  req.headers.contentType = ContentType.parse(contentType);
  if (declareContentLength) req.contentLength = body.length;
  final chunkSize = (body.length / chunkCount).ceil().clamp(1, body.length);
  for (var i = 0; i < body.length; i += chunkSize) {
    final end = (i + chunkSize < body.length) ? i + chunkSize : body.length;
    req.add(body.sublist(i, end));
  }
  // Do NOT await close() — extractBody() consumes the request stream on the
  // server side. Fire-and-forget so the test can run its assertions.
  unawaited(req.close().then((r) => r.drain<void>()).catchError((_) {}));

  final serverReq = await captured.future;
  addTearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });
  return serverReq;
}

void main() {
  group('RequestBody.extractBody', () {
    test(
      'when body size exceeds MAX_BODY_SIZE via declared content-length, aborts with 413',
      () async {
        final oversized = List<int>.filled(11 * 1024 * 1024, 65); // 11 MiB > 10
        final req = await _postWith(
          body: oversized,
          contentType: 'application/json',
        );
        // Respond so the client isn't left hanging even if we throw first.
        req.response.statusCode = 413;
        await expectLater(
          RequestBody.extractBody(request: req),
          throwsA(
            isA<HttpResponseException>().having((e) => e.code, 'code', 413),
          ),
        );
        await req.response.close();
      },
    );

    test(
      'when declared content-length lies (small) but stream is huge, still aborts 413',
      () async {
        final huge = List<int>.filled(11 * 1024 * 1024, 65);
        final req = await _postWith(
          body: huge,
          contentType: 'application/json',
          chunkCount: 20,
          declareContentLength: false,
        );
        req.response.statusCode = 413;
        await expectLater(
          RequestBody.extractBody(request: req),
          throwsA(
            isA<HttpResponseException>().having((e) => e.code, 'code', 413),
          ),
        );
        await req.response.close();
      },
    );

    test('when body under limit, returns parsed JSON map', () async {
      final body = '{"a":1,"b":"two"}';
      final req = await _postWith(
        body: body.codeUnits,
        contentType: 'application/json',
      );
      req.response.statusCode = 200;
      final parsed = await RequestBody.extractBody(request: req);
      expect(parsed, equals({'a': 1, 'b': 'two'}));
      await req.response.close();
    });
  });
}
