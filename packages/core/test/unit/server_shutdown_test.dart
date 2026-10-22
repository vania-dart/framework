import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/server/base_http_server.dart';

/// A server that answers `/slow` after [slowFor], everything else at once.
Future<BaseHttpServer> _serve(Duration slowFor) async {
  final server = BaseHttpServer(config: const {});
  final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.httpServer = http;
  http.listen((req) async {
    if (req.uri.path == '/slow') await Future<void>.delayed(slowFor);
    req.response.write('done');
    await req.response.close();
  });
  return server;
}

Future<String> _get(int port, String path) async {
  final client = HttpClient();
  try {
    final res = await (await client.get('127.0.0.1', port, path)).close();
    return '${res.statusCode} ${await res.transform(systemEncoding.decoder).join()}';
  } finally {
    client.close(force: true);
  }
}

void main() {
  test('an in-flight request finishes before shutdown completes, and new '
      'connections are refused', () async {
    final server = await _serve(const Duration(milliseconds: 500));
    final port = server.httpServer!.port;

    final inFlight = _get(port, '/slow');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final shutdown = server.shutdown(timeout: const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await expectLater(
      Socket.connect('127.0.0.1', port),
      throwsA(isA<SocketException>()),
    );

    expect(await inFlight, '200 done');
    await shutdown;
    expect(server.httpServer!.connectionsInfo().total, 0);
  });

  test('a request still running at the timeout is cut off', () async {
    final server = await _serve(const Duration(seconds: 30));
    final port = server.httpServer!.port;

    final stuck = _get(
      port,
      '/slow',
    ).then<Object?>((v) => v, onError: (e) => e);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final waited = Stopwatch()..start();
    await server.shutdown(timeout: const Duration(milliseconds: 300));
    expect(waited.elapsed, lessThan(const Duration(seconds: 2)));
    expect(await stuck, isA<HttpException>());
  });
}
