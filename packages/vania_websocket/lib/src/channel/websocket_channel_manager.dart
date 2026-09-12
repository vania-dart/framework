import 'dart:io';

import 'websocket_channel.dart';

class WebSocketChannelManager {
  static final WebSocketChannelManager _singleton = WebSocketChannelManager._();
  factory WebSocketChannelManager() => _singleton;
  WebSocketChannelManager._();

  final Map<String, WebSocketChannel> _channels = {};

  int get channelCount => _channels.length;

  bool get isEmpty => _channels.isEmpty;

  List<WebSocketChannel> get channels => _channels.values.toList();

  List<String> get channelIds => _channels.keys.toList();

  /// Create a new channel
  WebSocketChannel createChannel(
    String id, {
    String? name,
    Map<String, dynamic> metadata = const {},
  }) {
    if (_channels.containsKey(id)) {
      return _channels[id]!;
    }

    final channel = WebSocketChannel(
      id: id,
      name: name ?? id,
      metadata: metadata,
    );

    _channels[id] = channel;
    return channel;
  }

  /// Get a channel by ID
  WebSocketChannel? getChannel(String id) {
    return _channels[id];
  }

  /// Get or create a channel
  WebSocketChannel getOrCreateChannel(
    String id, {
    String? name,
    Map<String, dynamic> metadata = const {},
  }) {
    return _channels[id] ?? createChannel(id, name: name, metadata: metadata);
  }

  /// Delete a channel
  bool deleteChannel(String id) {
    final channel = _channels.remove(id);
    if (channel != null) {
      // Close all member connections in the channel
      for (final member in channel.members) {
        try {
          member.websocket.close(1000, 'Channel deleted');
        } catch (_) {
          // Already closed
        }
      }
      return true;
    }
    return false;
  }

  /// Join a channel
  bool joinChannel(
    String channelId,
    String sessionId,
    WebSocket ws, {
    Map<String, dynamic>? data,
  }) {
    final channel = getOrCreateChannel(channelId);
    channel.addMember(sessionId, ws, data: data);
    return true;
  }

  /// Leave a channel
  bool leaveChannel(String channelId, String sessionId) {
    final channel = _channels[channelId];
    if (channel != null) {
      channel.removeMember(sessionId);
      // Auto-delete empty channels
      if (channel.isEmpty) {
        _channels.remove(channelId);
      }
      return true;
    }
    return false;
  }

  /// Leave all channels for a session
  void leaveAllChannels(String sessionId) {
    final channelsToRemove = <String>[];

    for (final channel in _channels.values) {
      if (channel.hasMember(sessionId)) {
        channel.removeMember(sessionId);
        if (channel.isEmpty) {
          channelsToRemove.add(channel.id);
        }
      }
    }

    for (final channelId in channelsToRemove) {
      _channels.remove(channelId);
    }
  }

  /// Get all channels a session belongs to
  List<WebSocketChannel> getChannelsForSession(String sessionId) {
    return _channels.values
        .where((channel) => channel.hasMember(sessionId))
        .toList();
  }

  /// Get all session IDs in a channel
  List<String> getChannelMembers(String channelId) {
    return _channels[channelId]?.memberIds ?? [];
  }

  /// Emit to all members in a channel
  void emitToChannel(
    String channelId,
    String event,
    dynamic payload, {
    String? excludeSessionId,
  }) {
    final channel = _channels[channelId];
    channel?.emit(event, payload, excludeSessionId: excludeSessionId);
  }

  /// Emit to all channels
  void broadcast(String event, dynamic payload, {String? excludeSessionId}) {
    for (final channel in _channels.values) {
      channel.emit(event, payload, excludeSessionId: excludeSessionId);
    }
  }

  /// Check if session is in channel
  bool isMemberInChannel(String channelId, String sessionId) {
    return _channels[channelId]?.hasMember(sessionId) ?? false;
  }

  /// Get channel info
  Map<String, dynamic> getInfo(String channelId) {
    final channel = _channels[channelId];
    return channel?.toJson() ?? {};
  }

  /// Get all channels info
  List<Map<String, dynamic>> getAllInfo() {
    return _channels.values.map((c) => c.toJson()).toList();
  }

  /// Clear all channels
  void clear() {
    _channels.clear();
  }
}
