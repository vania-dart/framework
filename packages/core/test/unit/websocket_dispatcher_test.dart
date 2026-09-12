import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/websocket/websocket_upgrade_dispatcher.dart';

/// Opens a WebSocket upgrade request against [server] without waiting for a
/// response: some cases never write one, and the assertions are about what
/// the dispatcher did rather than what the client saw.
void _sendUpgrade(HttpServer server, {String path = '/ws'}) {
  final client = HttpClient();
  unawaited(
    client
        .get(InternetAddress.loopbackIPv4.address, server.port, path)
        .then((rq) {
          rq.headers
            ..set('connection', 'Upgrade')
            ..set('upgrade', 'websocket')
            ..set('sec-websocket-version', '13')
            ..set('sec-websocket-key', 'dGhlIHNhbXBsZSBub25jZQ==');
          return rq.close();
        })
        .then((res) => res.drain<void>())
        .catchError((_) {})
        .whenComplete(() => client.close(force: true)),
  );
}

void main() {
  late HttpServer server;

  setUp(() async {
    WebSocketUpgradeDispatcher().reset();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    WebSocketUpgradeDispatcher().reset();
    await server.close(force: true);
  });

  test('with no driver installed, an upgrade is refused rather than served',
      () async {
    final status = Completer<int>();
    server.listen((req) async {
      await WebSocketUpgradeDispatcher().dispatch(req);
      if (!status.isCompleted) status.complete(req.response.statusCode);
    });

    _sendUpgrade(server);

    // Core ships no WebSocket implementation; without a driver such as
    // vania_websocket there is nothing to hand the socket to.
    expect(await status.future, equals(HttpStatus.notImplemented));
  });

  test('a handler that throws surfaces the error to the awaiting caller',
      () async {
    WebSocketUpgradeDispatcher().override((req) async {
      throw StateError('handler blew up');
    });

    final caught = Completer<Object?>();
    server.listen((req) async {
      // Mirrors the WebSocket branch of RequestHandler.handle: the error has
      // to be catchable there, otherwise it escapes as an unhandled async
      // error with no response left to write.
      Object? error;
      try {
        await WebSocketUpgradeDispatcher().dispatch(req);
      } catch (e) {
        error = e;
      }
      if (!caught.isCompleted) caught.complete(error);
    });

    _sendUpgrade(server);

    expect(await caught.future, isA<StateError>());
  });

  test('an installed handler receives the upgrade', () async {
    final seen = Completer<String>();
    WebSocketUpgradeDispatcher().override((req) async {
      if (!seen.isCompleted) seen.complete(req.uri.path);
      await req.response.close();
    });

    server.listen((req) => WebSocketUpgradeDispatcher().dispatch(req));

    _sendUpgrade(server, path: '/chat');

    expect(await seen.future, equals('/chat'));
  });
}
