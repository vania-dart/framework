import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/response/response.dart';

/// Serves `Response.sse(events())` to every request.
Future<HttpServer> _serve(Stream<dynamic> Function() events) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) => Response.sse(events()).makeResponse(req.response));
  return server;
}

/// Opens a raw connection and returns everything the server sends on it.
Future<(Socket, Stream<String>)> _open(HttpServer server) async {
  final socket = await Socket.connect('127.0.0.1', server.port);
  socket.write('GET / HTTP/1.1\r\nHost: x\r\n\r\n');
  return (
    socket,
    socket.cast<List<int>>().transform(utf8.decoder).asBroadcastStream(),
  );
}

void main() {
  // Read once, on first use, so it is set before any stream starts.
  Env().env['SSE_HEARTBEAT'] = '1';

  late HttpServer server;
  tearDown(() => server.close(force: true));

  test('sends each event, then ends with the stream', () async {
    server = await _serve(
      () => Stream.fromIterable([
        1,
        'two',
        {'n': 3},
      ]),
    );
    final client = HttpClient();
    final res = await (await client.get('127.0.0.1', server.port, '/')).close();
    expect(res.headers.contentType?.mimeType, 'text/event-stream');
    expect(
      await res.transform(utf8.decoder).join(),
      'data: 1\n\ndata: "two"\n\ndata: {"n":3}\n\n',
    );
    client.close(force: true);
  });

  test('an event reaches the client as it happens, not when the stream '
      'ends', () async {
    final source = StreamController<int>();
    server = await _serve(() => source.stream);
    final (socket, received) = await _open(server);
    source.add(42);
    await received
        .firstWhere((s) => s.contains('data: 42'))
        .timeout(const Duration(seconds: 5));
    socket.destroy();
    await source.close();
  });

  test('a client that leaves releases the event source, even when the '
      'source is idle', () async {
    final cancelled = Completer<void>();
    server = await _serve(
      () => StreamController<int>(onCancel: cancelled.complete).stream,
    );

    final (socket, received) = await _open(server);
    await received.firstWhere((s) => s.contains('\r\n\r\n'));
    socket.destroy();

    await cancelled.future.timeout(const Duration(seconds: 5));
  });

  test('an idle stream sends a heartbeat comment', () async {
    server = await _serve(() => StreamController<int>().stream);
    final (socket, received) = await _open(server);
    await received
        .firstWhere((s) => s.contains(':\n\n'))
        .timeout(const Duration(seconds: 5));
    socket.destroy();
  });

  test('a failing event source ends the stream without taking the server '
      'down', () async {
    server = await _serve(
      () => Stream<int>.multi((c) {
        c.add(1);
        c.addError(StateError('source failed'));
      }),
    );
    final client = HttpClient();
    final res = await (await client.get('127.0.0.1', server.port, '/')).close();
    expect(await res.transform(utf8.decoder).join(), 'data: 1\n\n');
    client.close(force: true);
  });
}
