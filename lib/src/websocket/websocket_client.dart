import 'dart:convert';

import 'websocket_session.dart';

abstract class WebSocketClient {
  const WebSocketClient();
  String get clientId;
  List<String> get activeSessions;
  List<String> getRoomMembers({String roomId = ''});
  bool isActiveSession({String sessionId = ''});
  String get activeRoom;
  String get previousRoom;
  void emit(String event, dynamic payload);
  void toRoom(String event, String room, dynamic payload);
  void broadcast(String event, dynamic payload);
  void to(String clientId, String event, dynamic payload);
}

class WebSocketClientImpl implements WebSocketClient {
  final String id;
  final String routePath;
  final WebsocketSession session;
  const WebSocketClientImpl({
    required this.session,
    required this.id,
    required this.routePath,
  });

  @override
  String get clientId => id;

  @override
  List<String> get activeSessions => session.getActiveSessionIds();

  /// emit to self sender
  /// ```
  /// event.emit('event',payload)
  /// ```
  @override
  void emit(String event, dynamic payload) {
    SessionInfo? info = session.getWebSocketInfo(id);
    if (info != null) {
      info.websocket.add(jsonEncode({'event': event, 'payload': payload}));
    }
  }

  /// emit to room all users in room can see this message
  ///  exclude sender
  /// ```
  /// event.toRoom('event','room',payload)
  /// ```
  @override
  void toRoom(String event, String room, dynamic payload) {
    String roomId = room.replaceFirst('ws_', '');
    List<String> members = session.getRoomMembers('${routePath}_$roomId');
    for (String member in members) {
      SessionInfo? info = session.getWebSocketInfo(member);
      if (info != null) {
        info.websocket.add(jsonEncode({'event': event, 'payload': payload}));
      }
    }
  }

  /// emit to specific seesion id
  /// ```
  /// event.to(clientId,'event',payload)
  /// ```
  @override
  void to(String clientId, String event, dynamic payload) {
    SessionInfo? info = session.getWebSocketInfo(clientId);
    if (info != null) {
      info.websocket.add(jsonEncode({'event': event, 'payload': payload}));
    }
  }

  /// broadcast to all connected sessions exclude sender
  ///```
  /// event.broadcast('event',payload)
  /// ```
  @override
  void broadcast(String event, dynamic payload) {
    List<SessionInfo> sessions = session.getActiveSessions();
    sessions.removeWhere((item) => item.sessionId == id);
    sessions.shuffle();
    for (SessionInfo session in sessions) {
      session.websocket.add(jsonEncode({'event': event, 'payload': payload}));
    }
  }

  void joinRoom(String roomId) {
    toRoom("join-room", roomId, "join room");
  }

  void leftRoom(String roomId) {
    toRoom("left-room", roomId, "left room");
  }

  @override
  List<String> getRoomMembers({String roomId = ''}) =>
      session.getRoomMembers(roomId);

  @override
  String get activeRoom => session.getWebSocketInfo(id)?.activeRoom ?? '';

  @override
  String get previousRoom => session.getWebSocketInfo(id)?.previousRoom ?? '';

  @override
  bool isActiveSession({String sessionId = ''}) =>
      session.isActiveSession(sessionId);
}
