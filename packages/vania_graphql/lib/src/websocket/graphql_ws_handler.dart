import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vania/foundation.dart' show Logger;

import '../config/graphql_config.dart';
import '../context/graphql_context.dart';
import '../executor/vania_graphql_executor.dart';
import '../request/graphql_request.dart';

/// Implements the [`graphql-ws`](https://github.com/enisdenjo/graphql-ws)
/// sub-protocol on top of a single upgraded [WebSocket].
///
/// Wire protocol messages we handle:
///   client → server: `connection_init`, `subscribe`, `complete`, `ping`, `pong`
///   server → client: `connection_ack`, `next`, `complete`, `error`, `ping`, `pong`
///
/// One [GraphQLWsHandler] instance handles one WebSocket. It multiplexes
/// any number of subscriptions the client `subscribe`s to, keyed by the
/// per-request id the client picks.
class GraphQLWsHandler {
  GraphQLWsHandler(this.socket, {required this.executor, required this.config});

  final WebSocket socket;
  final VaniaGraphQLExecutor executor;
  final GraphQLConfig config;

  final Map<String, StreamSubscription<Map<String, dynamic>>> _subscriptions =
      {};
  Timer? _keepAlive;
  bool _initialized = false;
  bool _closed = false;

  static const String subprotocol = 'graphql-transport-ws';

  /// Start reading frames. Completes when the socket closes.
  Future<void> run() async {
    _startKeepAlive();
    try {
      await for (final raw in socket) {
        if (_closed) break;
        await _handleFrame(raw);
      }
    } catch (e, s) {
      Logger.log('GraphQLWsHandler socket error: $e\n$s', type: Logger.ERROR);
    } finally {
      await _tearDown();
    }
  }

  Future<void> _handleFrame(dynamic raw) async {
    Object? decoded;
    try {
      decoded = jsonDecode(raw is String ? raw : utf8.decode(raw));
    } catch (_) {
      return _closeWithCode(4400, 'Invalid JSON');
    }
    if (decoded is! Map) {
      return _closeWithCode(4400, 'Invalid message');
    }
    final message = Map<String, dynamic>.from(decoded);

    final type = message['type']?.toString();
    switch (type) {
      case 'connection_init':
        if (_initialized) {
          return _closeWithCode(4429, 'Too many initialisation requests');
        }
        _initialized = true;
        _send({'type': 'connection_ack'});
      case 'ping':
        _send({
          'type': 'pong',
          if (message['payload'] != null) 'payload': message['payload'],
        });
      case 'pong':
        // no-op — nothing to reply.
        break;
      case 'subscribe':
        await _handleSubscribe(message);
      case 'complete':
        await _cancelSubscription(message['id']?.toString());
      default:
        return _closeWithCode(4400, 'Unknown message type: $type');
    }
  }

  Future<void> _handleSubscribe(Map<String, dynamic> message) async {
    if (!_initialized) {
      return _closeWithCode(4401, 'Unauthorized');
    }
    final id = message['id']?.toString();
    if (id == null || id.isEmpty) {
      return _closeWithCode(4400, '`id` is required for subscribe');
    }
    if (_subscriptions.containsKey(id)) {
      return _closeWithCode(4409, 'Subscriber for $id already exists');
    }

    final payloadDynamic = message['payload'];
    if (payloadDynamic is! Map) {
      return _send({
        'type': 'error',
        'id': id,
        'payload': [
          {'message': 'GraphQL payload must be an object.'},
        ],
      });
    }
    final payload = Map<String, dynamic>.from(payloadDynamic);

    VaniaGraphQLRequest request;
    try {
      request = VaniaGraphQLRequest.fromMap(
        payload,
        context: VaniaGraphQLContext(),
      );
    } on VaniaGraphQLRequestException catch (e) {
      return _send({
        'type': 'error',
        'id': id,
        'payload': [
          {'message': e.message},
        ],
      });
    }

    final result = await executor.execute(request);

    if (result.isStream) {
      final sub = result.stream!.listen(
        (event) => _send({'type': 'next', 'id': id, 'payload': event}),
        onError: (Object error, StackTrace s) {
          _send({
            'type': 'error',
            'id': id,
            'payload': [
              {'message': error.toString()},
            ],
          });
          _subscriptions.remove(id);
        },
        onDone: () {
          _send({'type': 'complete', 'id': id});
          _subscriptions.remove(id);
        },
      );
      _subscriptions[id] = sub;
      return;
    }

    // Non-streaming payload — send one `next` then `complete`.
    final payloadOut = result.payload ?? const <String, dynamic>{};
    if (payloadOut.containsKey('errors') && !payloadOut.containsKey('data')) {
      _send({'type': 'error', 'id': id, 'payload': payloadOut['errors']});
    } else {
      _send({'type': 'next', 'id': id, 'payload': payloadOut});
    }
    _send({'type': 'complete', 'id': id});
  }

  Future<void> _cancelSubscription(String? id) async {
    if (id == null) return;
    final sub = _subscriptions.remove(id);
    await sub?.cancel();
  }

  void _send(Map<String, dynamic> message) {
    if (_closed) return;
    try {
      socket.add(jsonEncode(message));
    } catch (_) {
      // Socket vanished mid-write; the run loop will notice on next read.
    }
  }

  void _startKeepAlive() {
    final interval = config.keepAliveInterval;
    if (interval <= Duration.zero) return;
    _keepAlive = Timer.periodic(interval, (_) {
      if (_closed) return;
      _send({'type': 'ping'});
    });
  }

  Future<void> _closeWithCode(int code, String reason) async {
    if (_closed) return;
    _closed = true;
    try {
      await socket.close(code, reason);
    } catch (_) {}
    await _tearDown();
  }

  Future<void> _tearDown() async {
    _closed = true;
    _keepAlive?.cancel();
    for (final sub in _subscriptions.values) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }
}
