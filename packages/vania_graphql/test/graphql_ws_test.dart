import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/websocket.dart' show WebSocketUpgradeDispatcher;
import 'package:vania_graphql/vania_graphql.dart';

/// Boot an HTTP server bound to an ephemeral port and route every upgrade
/// through [WebSocketUpgradeDispatcher] — mirrors what
/// `BaseHttpServer.startServer` does in production.
Future<HttpServer> _startServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      await WebSocketUpgradeDispatcher().dispatch(request);
      return;
    }
    request.response
      ..statusCode = HttpStatus.notFound
      ..close();
  });
  return server;
}

GraphQLSchema _schema() {
  return graphQLSchema(
    queryType: objectType(
      'Query',
      fields: [
        vaniaField<String, String>(
          'hello',
          graphQLString,
          resolve: (_, _) => 'world',
        ),
      ],
    ),
    subscriptionType: objectType(
      'Subscription',
      fields: [
        vaniaSubscriptionField<String, String>(
          'ticks',
          graphQLString,
          resolve: (_, _) => Stream.fromIterable([
            {'ticks': 'a'},
            {'ticks': 'b'},
            {'ticks': 'c'},
          ]),
        ),
      ],
    ),
  );
}

void main() {
  setUp(() {
    WebSocketUpgradeDispatcher().reset();
    GraphQLSchemaRegistry().reset();
  });

  tearDown(() {
    WebSocketUpgradeDispatcher().reset();
    GraphQLSchemaRegistry().reset();
  });

  group('GraphQLWsDispatcher', () {
    test(
      'routes /graphql/ws upgrades through the graphql-ws handler',
      () async {
        GraphQLSchemaRegistry().registerSchema(_schema());
        GraphQLWsDispatcher(
          const GraphQLConfig(
            subscriptionsEndpoint: '/graphql/ws',
            keepAliveInterval: Duration(hours: 1),
          ),
        ).install();

        final server = await _startServer();
        addTearDown(() async => server.close(force: true));

        final ws = await WebSocket.connect(
          'ws://${server.address.host}:${server.port}/graphql/ws',
          protocols: [GraphQLWsHandler.subprotocol],
        );
        addTearDown(ws.close);

        final events = <Map<String, dynamic>>[];
        final done = Completer<void>();
        ws.listen(
          (raw) {
            final m = Map<String, dynamic>.from(jsonDecode(raw as String));
            events.add(m);
            if (m['type'] == 'complete') done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );

        ws.add(jsonEncode({'type': 'connection_init'}));
        // Wait for ack before subscribing.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        ws.add(
          jsonEncode({
            'type': 'subscribe',
            'id': 's1',
            'payload': {'query': 'subscription { ticks }'},
          }),
        );

        await done.future.timeout(const Duration(seconds: 3));

        final types = events.map((e) => e['type']).toList();
        expect(types.first, 'connection_ack');
        expect(types.where((t) => t == 'next').length, 3);
        expect(types.last, 'complete');
      },
    );

    test('non-matching paths fall through to the previous handler', () async {
      var otherCalled = false;
      final completer = Completer<void>();
      WebSocketUpgradeDispatcher().override((request) async {
        otherCalled = true;
        final ws = await WebSocketTransformer.upgrade(request);
        await ws.close();
        completer.complete();
      });

      GraphQLWsDispatcher(
        const GraphQLConfig(subscriptionsEndpoint: '/graphql/ws'),
      ).install();

      final server = await _startServer();
      addTearDown(() async => server.close(force: true));

      final ws = await WebSocket.connect(
        'ws://${server.address.host}:${server.port}/some/other/path',
      );
      await ws.close();
      await completer.future.timeout(const Duration(seconds: 2));

      expect(otherCalled, isTrue);
    });
  });

  group('GraphQLWsHandler', () {
    test('runs a one-shot query and closes the subscription', () async {
      GraphQLSchemaRegistry().registerSchema(_schema());
      GraphQLWsDispatcher(
        const GraphQLConfig(
          subscriptionsEndpoint: '/graphql/ws',
          keepAliveInterval: Duration(hours: 1),
        ),
      ).install();

      final server = await _startServer();
      addTearDown(() async => server.close(force: true));

      final ws = await WebSocket.connect(
        'ws://${server.address.host}:${server.port}/graphql/ws',
        protocols: [GraphQLWsHandler.subprotocol],
      );
      addTearDown(ws.close);

      final events = <Map<String, dynamic>>[];
      final done = Completer<void>();
      ws.listen((raw) {
        final m = Map<String, dynamic>.from(jsonDecode(raw as String));
        events.add(m);
        if (m['type'] == 'complete') done.complete();
      });

      ws.add(jsonEncode({'type': 'connection_init'}));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      ws.add(
        jsonEncode({
          'type': 'subscribe',
          'id': 'q1',
          'payload': {'query': '{ hello }'},
        }),
      );

      await done.future.timeout(const Duration(seconds: 3));

      // ack + next + complete
      expect(events.map((e) => e['type']).toList(), [
        'connection_ack',
        'next',
        'complete',
      ]);
      expect(events[1]['payload']['data']['hello'], 'world');
    });
  });
}
