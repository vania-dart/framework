import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania_websocket/vania_websocket.dart';

void main() {
  group('WebSocketPresence', () {
    late _SocketPair pair;
    late WebSocketPresence presence;

    setUp(() async {
      pair = await _SocketPair.open();
      presence = WebSocketPresence();
      presence.clear();
    });

    tearDown(() async {
      presence.clear();
      await pair.close();
    });

    test('broadcast sends valid JSON messages', () async {
      presence.userConnected(
        'user-1',
        sessionId: 'session-1',
        websocket: pair.serverSocket,
        data: {'name': 'Ava'},
      );

      presence.broadcast('notice', {'text': 'hello'});

      final decoded = await pair.nextClientMessage();
      expect(decoded['event'], equals('notice'));
      expect(decoded['payload'], equals({'text': 'hello'}));
    });

    test('disconnecting by session removes the user presence', () {
      presence.userConnected(
        'user-1',
        sessionId: 'session-1',
        websocket: pair.serverSocket,
      );

      presence.userDisconnectedSession('session-1');

      expect(presence.isOnline('user-1'), isFalse);
      expect(presence.onlineCount, equals(0));
    });
  });

  group('WebSocketRateLimiter', () {
    test('uses a deterministic clock and recovers after the window', () {
      var now = DateTime(2026, 1, 1, 12);
      final limiter = WebSocketRateLimiter(
        maxRequests: 2,
        window: const Duration(seconds: 10),
        clock: () => now,
      );

      expect(limiter.isAllowed('client'), isTrue);
      expect(limiter.isAllowed('client'), isTrue);
      expect(limiter.isAllowed('client'), isFalse);
      expect(limiter.remaining('client'), equals(0));

      now = now.add(const Duration(seconds: 11));

      expect(limiter.isAllowed('client'), isTrue);
      expect(limiter.remaining('client'), equals(1));
    });
  });

  group('WebSocketChannelManager', () {
    late _SocketPair firstPair;
    late _SocketPair secondPair;
    late WebSocketChannelManager manager;

    setUp(() async {
      firstPair = await _SocketPair.open();
      secondPair = await _SocketPair.open();
      manager = WebSocketChannelManager();
      manager.clear();
    });

    tearDown(() async {
      manager.clear();
      await firstPair.close();
      await secondPair.close();
    });

    test(
      'joining is idempotent and excluded members do not receive emits',
      () async {
        manager.joinChannel('chat', 'session-1', firstPair.serverSocket);
        manager.joinChannel('chat', 'session-1', firstPair.serverSocket);
        manager.joinChannel('chat', 'session-2', secondPair.serverSocket);

        manager.emitToChannel('chat', 'message', {
          'text': 'hello',
        }, excludeSessionId: 'session-1');

        expect(manager.getChannelMembers('chat'), hasLength(2));
        expect(
          await secondPair.nextClientMessage(),
          containsPair('event', 'message'),
        );
        await expectLater(
          firstPair.nextClientMessage(
            timeout: const Duration(milliseconds: 100),
          ),
          throwsA(isA<TimeoutException>()),
        );
      },
    );
  });

  group('WebSocketEventHandler', () {
    test('middleware can stop the handler', () async {
      final handler = WebSocketEventHandler();
      var called = false;

      handler.middleware('blocked', (_, _, _) async => false);
      handler.on('blocked', (_, _, _) async {
        called = true;
      });

      final pair = await _SocketPair.open();
      addTearDown(pair.close);

      final handled = await handler.handle(
        'blocked',
        {},
        pair.serverSocket,
        const {},
      );

      expect(handled, isFalse);
      expect(called, isFalse);
    });
  });

  group('VaniaWebSocketService', () {
    late HttpServer server;
    late VaniaWebSocketService service;

    setUp(() async {
      service = VaniaWebSocketService();
      service.init(
        config: WebSocketConfig(enablePresence: false, maxRoomsPerClient: 2),
      );
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(service.handle);
    });

    tearDown(() async {
      service.closeAll();
      await server.close(force: true);
    });

    test('tracks joined rooms and emits to public room names', () async {
      final socket = await WebSocket.connect(
        'ws://${InternetAddress.loopbackIPv4.address}:${server.port}/chat',
      );
      addTearDown(socket.close);
      final messages = StreamIterator(socket);

      await messages.moveNext();
      final connected = jsonDecode(messages.current as String) as Map;
      final sessionId = connected['payload']['session_id'] as String;

      socket.add(
        jsonEncode({
          'event': 'join-room',
          'payload': {'room': 'lobby'},
        }),
      );

      await messages.moveNext();
      final joined = jsonDecode(messages.current as String) as Map;
      expect(joined['event'], equals('joined-room'));
      expect(service.getRoomMembers('lobby'), contains(sessionId));

      service.emitToRoom('lobby', 'notice', {'text': 'hello room'});

      await messages.moveNext();
      final notice = jsonDecode(messages.current as String) as Map;
      expect(notice['event'], equals('notice'));
      expect(notice['payload'], equals({'text': 'hello room'}));
    });
  });
}

class _SocketPair {
  _SocketPair._({
    required this.server,
    required this.serverSocket,
    required this.clientSocket,
  });

  final HttpServer server;
  final WebSocket serverSocket;
  final WebSocket clientSocket;

  static Future<_SocketPair> open() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverSocketFuture = server.first.then(WebSocketTransformer.upgrade);
    final clientSocket = await WebSocket.connect(
      'ws://${InternetAddress.loopbackIPv4.address}:${server.port}',
    );
    final serverSocket = await serverSocketFuture;
    return _SocketPair._(
      server: server,
      serverSocket: serverSocket,
      clientSocket: clientSocket,
    );
  }

  Future<Map<String, dynamic>> nextClientMessage({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final raw = await clientSocket.first.timeout(timeout);
    return jsonDecode(raw as String) as Map<String, dynamic>;
  }

  Future<void> close() async {
    await serverSocket.close();
    await clientSocket.close();
    await server.close(force: true);
  }
}
