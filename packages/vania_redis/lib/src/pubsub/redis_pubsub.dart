import 'dart:async';

import 'package:redis/redis.dart' as redis;

/// A single message delivered on a Redis Pub/Sub subscription.
class RedisMessage<T> {
  const RedisMessage({
    required this.kind,
    required this.channel,
    required this.payload,
    this.pattern,
  });

  /// Either `"message"` (subscribe) or `"pmessage"` (psubscribe).
  final String kind;

  /// The channel the message was published on.
  final String channel;

  /// The message payload — typically a `String` for the default codec.
  final T payload;

  /// The pattern that matched when [kind] == `"pmessage"`; otherwise `null`.
  final String? pattern;
}

/// A subscription-side Redis Pub/Sub session.
///
/// Redis dedicates a connection to Pub/Sub while it holds any subscription,
/// so [RedisPubSub] owns its own [redis.RedisConnection]. Call [close] when
/// done to unsubscribe and release the connection.
class RedisPubSub<T> {
  RedisPubSub._(this._pubSub, this._connection, this.stream);

  final redis.PubSub _pubSub;
  final redis.RedisConnection? _connection;
  bool _closed = false;

  /// Stream of typed messages. Filtering for `message`/`pmessage` events
  /// happens upstream — the stream never yields subscribe/unsubscribe acks.
  final Stream<RedisMessage<T>> stream;

  /// Attaches Pub/Sub semantics to an existing [redis.Command]. The
  /// underlying connection is NOT owned by the [RedisPubSub], so [close]
  /// will not attempt to close it. Prefer [attach] when you manage the
  /// command yourself.
  static RedisPubSub<T> attach<T>(
    redis.Command command, {
    List<String> channels = const [],
    List<String> patterns = const [],
  }) => _wrap<T>(command, channels, patterns, connection: null);

  /// Attach Pub/Sub semantics to [command] AND take ownership of [connection].
  /// [close] will unsubscribe and close the connection.
  static RedisPubSub<T> own<T>(
    redis.Command command,
    redis.RedisConnection connection, {
    List<String> channels = const [],
    List<String> patterns = const [],
  }) => _wrap<T>(command, channels, patterns, connection: connection);

  @Deprecated('Use RedisPubSub.attach or RedisPubSub.own.')
  static RedisPubSub<T> create<T>(
    redis.Command command,
    List<String> channels,
    List<String> patterns,
  ) => attach<T>(command, channels: channels, patterns: patterns);

  static RedisPubSub<T> _wrap<T>(
    redis.Command command,
    List<String> channels,
    List<String> patterns, {
    required redis.RedisConnection? connection,
  }) {
    final pubSub = redis.PubSub(command);
    if (channels.isNotEmpty) pubSub.subscribe(channels);
    if (patterns.isNotEmpty) pubSub.psubscribe(patterns);

    final stream = pubSub
        .getStream()
        .where(
          (event) =>
              event is List &&
              (event[0] == 'message' || event[0] == 'pmessage'),
        )
        .map((event) {
          final data = event as List;
          if (data[0] == 'pmessage') {
            return RedisMessage<T>(
              kind: data[0].toString(),
              pattern: data[1].toString(),
              channel: data[2].toString(),
              payload: data[3] as T,
            );
          }
          return RedisMessage<T>(
            kind: data[0].toString(),
            channel: data[1].toString(),
            payload: data[2] as T,
          );
        });

    return RedisPubSub<T>._(pubSub, connection, stream);
  }

  /// Subscribe to additional channels.
  void subscribe(List<String> channels) {
    _guard();
    _pubSub.subscribe(channels);
  }

  /// Subscribe to additional patterns.
  void psubscribe(List<String> patterns) {
    _guard();
    _pubSub.psubscribe(patterns);
  }

  /// Unsubscribe from [channels].
  void unsubscribe(List<String> channels) {
    _guard();
    _pubSub.unsubscribe(channels);
  }

  /// Unsubscribe from [patterns].
  void punsubscribe(List<String> patterns) {
    _guard();
    _pubSub.punsubscribe(patterns);
  }

  /// Whether [close] has been called.
  bool get isClosed => _closed;

  /// Unsubscribe from everything and, if this session owns its connection,
  /// close it. Safe to call more than once.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      _pubSub.unsubscribe(const <String>[]);
    } catch (_) {}
    try {
      _pubSub.punsubscribe(const <String>[]);
    } catch (_) {}
    await _connection?.close();
  }

  void _guard() {
    if (_closed) {
      throw StateError('RedisPubSub has been closed');
    }
  }
}
