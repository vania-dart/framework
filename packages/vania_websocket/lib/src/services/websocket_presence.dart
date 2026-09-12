import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WebSocketPresence {
  static final WebSocketPresence _singleton = WebSocketPresence._();
  factory WebSocketPresence() => _singleton;
  WebSocketPresence._();

  final Map<String, PresenceInfo> _users = {};
  final Map<String, String> _sessionToUser = {};
  final Expando<_PendingPresence> _pendingPresence =
      Expando<_PendingPresence>();
  final StreamController<PresenceEvent> _eventController =
      StreamController<PresenceEvent>.broadcast();

  Stream<PresenceEvent> get onPresenceChanged => _eventController.stream;

  int get onlineCount => _users.length;

  bool get isEmpty => _users.isEmpty;

  List<PresenceInfo> get onlineUsers => _users.values.toList();

  List<String> get onlineUserIds => _users.keys.toList();

  /// User comes online
  void userConnected(
    String userId, {
    required String sessionId,
    required WebSocket websocket,
    Map<String, dynamic>? data,
  }) {
    final info = PresenceInfo(
      userId: userId,
      sessionId: sessionId,
      websocket: websocket,
      connectedAt: DateTime.now(),
      data: data ?? {},
    );

    _users[userId] = info;
    _sessionToUser[sessionId] = userId;

    _eventController.add(
      PresenceEvent(
        type: PresenceEventType.connected,
        userId: userId,
        data: data,
      ),
    );
  }

  /// User goes offline
  void userDisconnected(String userId) {
    final info = _users.remove(userId);
    if (info != null) {
      _sessionToUser.remove(info.sessionId);
      _eventController.add(
        PresenceEvent(type: PresenceEventType.disconnected, userId: userId),
      );
    }
  }

  void userDisconnectedSession(String sessionId) {
    final userId = _sessionToUser[sessionId];
    if (userId == null) return;
    userDisconnected(userId);
  }

  void rememberAuthenticatedUser(
    HttpRequest request, {
    required String? userId,
    Map<String, dynamic> data = const {},
  }) {
    if (userId == null || userId.isEmpty) return;
    _pendingPresence[request] = _PendingPresence(userId: userId, data: data);
  }

  void connectRememberedUser(
    HttpRequest request, {
    required String sessionId,
    required WebSocket websocket,
  }) {
    final pending = _pendingPresence[request];
    if (pending == null) return;
    userConnected(
      pending.userId,
      sessionId: sessionId,
      websocket: websocket,
      data: pending.data,
    );
    _pendingPresence[request] = null;
  }

  /// Check if user is online
  bool isOnline(String userId) {
    return _users.containsKey(userId);
  }

  /// Get user presence info
  PresenceInfo? getUser(String userId) {
    return _users[userId];
  }

  /// Update user data
  void updateData(String userId, Map<String, dynamic> data) {
    final info = _users[userId];
    if (info != null) {
      info.data.addAll(data);
      _eventController.add(
        PresenceEvent(
          type: PresenceEventType.updated,
          userId: userId,
          data: data,
        ),
      );
    }
  }

  /// Broadcast to all online users
  void broadcast(String event, dynamic payload, {String? excludeUserId}) {
    for (final entry in _users.entries) {
      if (excludeUserId != null && entry.key == excludeUserId) {
        continue;
      }
      try {
        entry.value.websocket.add(_encodeMessage(event, payload));
      } catch (_) {
        // Connection might be closed
      }
    }
  }

  /// Send to specific user
  void sendToUser(String userId, String event, dynamic payload) {
    final info = _users[userId];
    if (info != null) {
      try {
        info.websocket.add(_encodeMessage(event, payload));
      } catch (_) {
        // Connection might be closed
      }
    }
  }

  /// Get user count in specific channel
  int getUserCount(List<String> userIds) {
    return userIds.where((id) => _users.containsKey(id)).length;
  }

  /// Get online users info
  List<Map<String, dynamic>> getOnlineUsersInfo() {
    return _users.values.map((info) => info.toJson()).toList();
  }

  /// Clear all presence data
  void clear() {
    _users.clear();
    _sessionToUser.clear();
  }

  String _encodeMessage(String event, dynamic payload) {
    return jsonEncode({'event': event, 'payload': payload});
  }

  void dispose() {
    _eventController.close();
  }
}

class _PendingPresence {
  final String userId;
  final Map<String, dynamic> data;

  const _PendingPresence({required this.userId, required this.data});
}

class PresenceInfo {
  final String userId;
  final String sessionId;
  final WebSocket websocket;
  final DateTime connectedAt;
  final Map<String, dynamic> data;

  PresenceInfo({
    required this.userId,
    required this.sessionId,
    required this.websocket,
    required this.connectedAt,
    this.data = const {},
  });

  Duration get onlineDuration => DateTime.now().difference(connectedAt);

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'session_id': sessionId,
      'connected_at': connectedAt.toIso8601String(),
      'online_duration': onlineDuration.inSeconds,
      'data': data,
    };
  }
}

enum PresenceEventType { connected, disconnected, updated }

class PresenceEvent {
  final PresenceEventType type;
  final String userId;
  final Map<String, dynamic>? data;

  PresenceEvent({required this.type, required this.userId, this.data});
}
