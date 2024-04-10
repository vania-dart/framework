import 'dart:convert';

import 'websocket_session.dart';

abstract class WebSocketClient {
  const WebSocketClient();
  String get clientId;
  void emit(String event, dynamic payload);
  void toRoom(String event, String room, dynamic payload);
  void broadcast(String event, dynamic payload);
  void to(String clientId, String event, dynamic payload);
}

class WebSocketClientImpl implements WebSocketClient {
  final String id;
  final WebsocketSession session;
  const WebSocketClientImpl({required this.session, required this.id});

  @override
  String get clientId => id;

  /// emit to self sender
  /// ```
  /// event.emit('event',payload)
  /// ```
  @override
  void emit(String event, dynamic payload) {
    SessionInfo? info = session.getWebSocketInfo(id);
    if (info != null) {
      info.websocket.add(jsonEncode({
        'event': event,
        'payload': payload,
      }));
    }
  }

  /// emit to room all users in room can see this message
  ///  exclude sender
  /// ```
  /// event.toRoom('event','room',payload)
  /// ```
  @override
  void toRoom(String event, String room, dynamic payload) {
    List<String> members = session.getRoomMembers(room);
    for (String member in members) {
      if (id != member) {
        SessionInfo? info = session.getWebSocketInfo(member);
        if (info != null) {
          info.websocket.add(jsonEncode({
            'event': event,
            'payload': payload,
          }));
        }
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
      info.websocket.add(jsonEncode({
        'event': event,
        'payload': payload,
      }));
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
      session.websocket.add(jsonEncode({
        'event': event,
        'payload': payload,
      }));
    }
  }

  void joinRoom(String roomId) {
    //emit('joinRoom', 'Join Room');
    toRoom("joinRoom", roomId, "$clientId join room");
  }

  void leftRoom(String roomId) {
    //emit('leftRoom', 'Left Room');
    toRoom("leftRoom", roomId, "$clientId left room");
  }
}
