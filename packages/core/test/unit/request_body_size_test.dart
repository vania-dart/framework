import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/exception/http_exception.dart';
import 'package:vania/src/http/request/request_body.dart';
import 'package:vania/src/http/request/request_file.dart';

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

    // A chunked upload declares no Content-Length, so only counting the
    // bytes as they stream in can enforce the cap.
    List<int> multipart({required String disposition, required int size}) => [
      ...'--XyZ\r\nContent-Disposition: form-data; $disposition\r\n\r\n'
          .codeUnits,
      ...List<int>.filled(size, 65),
      ...'\r\n--XyZ--\r\n'.codeUnits,
    ];

    for (final (kind, disposition) in [
      ('text field', 'name="note"'),
      ('file', 'name="upload"; filename="big.bin"'),
    ]) {
      test(
        'when a chunked multipart $kind exceeds MAX_BODY_SIZE, aborts 413',
        () async {
          final req = await _postWith(
            body: multipart(disposition: disposition, size: 11 * 1024 * 1024),
            contentType: 'multipart/form-data; boundary=XyZ',
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
    }

    test(
      'when a chunked multipart body is under the limit, parses it',
      () async {
        final req = await _postWith(
          body: multipart(disposition: 'name="note"', size: 1024),
          contentType: 'multipart/form-data; boundary=XyZ',
          chunkCount: 4,
          declareContentLength: false,
        );
        req.response.statusCode = 200;
        final parsed = await RequestBody.extractBody(request: req);
        expect(parsed['note'], 'A' * 1024);
        await req.response.close();
      },
    );

    test(
      'when a chunked multipart file is under the limit, its bytes are readable',
      () async {
        final req = await _postWith(
          body: multipart(
            disposition: 'name="upload"; filename="a.bin"',
            size: 300 * 1024,
          ),
          contentType: 'multipart/form-data; boundary=XyZ',
          chunkCount: 8,
          declareContentLength: false,
        );
        req.response.statusCode = 200;
        final parsed = await RequestBody.extractBody(request: req);
        final file = parsed['upload'] as RequestFile;
        expect(await file.size, 300 * 1024);
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
