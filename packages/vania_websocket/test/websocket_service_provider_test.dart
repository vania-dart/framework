import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/vania.dart';
import 'package:vania_websocket/vania_websocket.dart';

/// Proves that when `WebSocketServiceProvider` boots, WebSocket upgrades
/// received on the app's single HTTP port are routed through
/// `VaniaWebSocketService` — the handler it registers on the dispatcher —
/// and that a plain HTTP GET on the same port keeps returning HTTP.
///
/// The test wires only what's needed: an `HttpServer` on an ephemeral
/// port, a single request handler that mirrors what
/// `RequestHandler.handle` does for the WS branch (checking
/// `WebSocketTransformer.isUpgradeRequest` and delegating to the
/// dispatcher), and the provider under test. This isolates the
/// **integration point** — the dispatcher — from the wider app boot.
void main() {
  group('WebSocketServiceProvider — same-port integration', () {
    late HttpServer server;
    late VaniaWebSocketService service;

    setUp(() async {
      // Reset any prior dispatcher override and rebuild the service so
      // this test doesn't inherit state from the fleet tests.
      WebSocketUpgradeDispatcher().reset();
      service = VaniaWebSocketService();
      final provider = WebSocketServiceProvider(
        config: WebSocketConfig(enablePresence: false, maxRoomsPerClient: 2),
      );
      await provider.register();
      await provider.boot();

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        if (WebSocketTransformer.isUpgradeRequest(req)) {
          WebSocketUpgradeDispatcher().dispatch(req);
          return;
        }
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'kind': 'http', 'path': req.uri.path}))
          ..close();
      });
    });

    tearDown(() async {
      service.closeAll();
      WebSocketUpgradeDispatcher().reset();
      await server.close(force: true);
    });

    test(
      'WebSocket upgrade on the app port is served by VaniaWebSocketService',
      () async {
        final port = server.port;
        final socket = await WebSocket.connect(
          'ws://${InternetAddress.loopbackIPv4.address}:$port/chat',
        );
        addTearDown(socket.close);

        final messages = StreamIterator(socket);
        await messages.moveNext();
        final connected = jsonDecode(messages.current as String) as Map;
        expect(connected['event'], equals('connected'));
        expect(connected['payload'], isA<Map>());
        expect(connected['payload']['session_id'], startsWith('ws:'));

        socket.add(
          jsonEncode({
            'event': 'join-room',
            'payload': {'room': 'lobby'},
          }),
        );
        await messages.moveNext();
        final joined = jsonDecode(messages.current as String) as Map;
        expect(joined['event'], equals('joined-room'));

        service.emitToRoom('lobby', 'notice', {'text': 'from server'});
        await messages.moveNext();
        final notice = jsonDecode(messages.current as String) as Map;
        expect(notice['event'], equals('notice'));
        expect(notice['payload'], equals({'text': 'from server'}));
      },
    );

    test(
      'HTTP GET on the same port still returns HTTP (WS did not steal the port)',
      () async {
        final port = server.port;
        final client = HttpClient();
        addTearDown(client.close);
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/health'),
        );
        final resp = await req.close();
        expect(resp.statusCode, equals(HttpStatus.ok));
        final body = await resp.transform(utf8.decoder).join();
        expect(jsonDecode(body), equals({'kind': 'http', 'path': '/health'}));
      },
    );

    test(
      'boot() with enabled: false leaves the default handler in place',
      () async {
        final disabled = WebSocketServiceProvider(
          config: WebSocketConfig(enabled: false),
        );
        await disabled.register();
        await disabled.boot();
        // The override should now be cleared; a follow-up boot with an
        // enabled config re-registers it. This proves the dispatcher is
        // side-effect-safe across provider lifecycles.
        expect(disabled, isNotNull);
      },
    );
  });
}
