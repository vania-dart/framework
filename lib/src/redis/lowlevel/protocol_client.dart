import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:vania/src/redis/exception.dart';
import 'package:vania/src/redis/lowlevel/resp.dart';

/// low level Redis Client
class RedisProtocolClient {
  final Socket _socket;
  final Queue<Completer<Resp>> _waitingCompleter = ListQueue<Completer<Resp>>();
  final Stream<List<int>> _stream;

  RedisProtocolClient._(this._socket) : _stream = _socket.asBroadcastStream() {
    _stream.listen(_onData);
  }

  /// create [RedisProtocolClient]'s instance
  static Future<RedisProtocolClient> createConnection({
    required String host,
    required int port,
  }) async {
    final sock = await Socket.connect(host, port)
      ..setOption(SocketOption.tcpNoDelay, true);
    return RedisProtocolClient._(sock);
  }

  /// event handling on data received
  void _onData(List<int> data) {
    final str = utf8.decode(data);
    if (_waitingCompleter.isEmpty) {
      return;
    }
    final f = _waitingCompleter.removeFirst();
    final resp = Resp.deserialize(str);
    if (resp == null) {
      f.completeError(RedisConvertException('failed to convert'));
      return;
    }
    f.complete(resp);
  }

  /// send Redis command data.
  /// [resp]: redis command
  void sendCommand(Resp resp) {
    _socket.add(utf8.encode(resp.serialize()));
  }

  /// receive command
  Future<Resp> receive() {
    final c = Completer<Resp>();
    _waitingCompleter.addLast(c);
    return c.future;
  }

  /// received data stream
  Stream<Resp?> get stream => _stream
      .map((event) => utf8.decode(event))
      .map((event) => Resp.deserialize(event));

  /// close connection
  Future<void> close() => _socket.close();
}
