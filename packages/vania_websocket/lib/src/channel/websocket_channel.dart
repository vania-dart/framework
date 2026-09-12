import 'dart:convert';
import 'dart:io';

class WebSocketChannel {
  final String id;
  final String name;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  WebSocketChannel({
    required this.id,
    required this.name,
    this.metadata = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final Map<String, WebSocketChannelMember> _members = {};

  int get memberCount => _members.length;

  bool get isEmpty => _members.isEmpty;

  bool get isNotEmpty => _members.isNotEmpty;

  List<WebSocketChannelMember> get members => _members.values.toList();

  List<String> get memberIds => _members.keys.toList();

  void addMember(String sessionId, WebSocket ws, {Map<String, dynamic>? data}) {
    _members[sessionId] = WebSocketChannelMember(
      sessionId: sessionId,
      websocket: ws,
      data: data ?? {},
      joinedAt: DateTime.now(),
    );
  }

  void removeMember(String sessionId) {
    _members.remove(sessionId);
  }

  bool hasMember(String sessionId) {
    return _members.containsKey(sessionId);
  }

  WebSocketChannelMember? getMember(String sessionId) {
    return _members[sessionId];
  }

  void emit(String event, dynamic payload, {String? excludeSessionId}) {
    final message = jsonEncode({
      'event': event,
      'payload': payload,
      'channel': id,
    });

    for (final entry in _members.entries) {
      if (excludeSessionId != null && entry.key == excludeSessionId) {
        continue;
      }
      try {
        entry.value.websocket.add(message);
      } catch (_) {
        // Connection might be closed
      }
    }
  }

  void emitTo(String sessionId, String event, dynamic payload) {
    final member = _members[sessionId];
    if (member != null) {
      try {
        member.websocket.add(
          jsonEncode({'event': event, 'payload': payload, 'channel': id}),
        );
      } catch (_) {
        // Connection might be closed
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'member_count': memberCount,
    };
  }
}

class WebSocketChannelMember {
  final String sessionId;
  final WebSocket websocket;
  final Map<String, dynamic> data;
  final DateTime joinedAt;

  WebSocketChannelMember({
    required this.sessionId,
    required this.websocket,
    this.data = const {},
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'data': data,
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}
