import 'dart:collection';
import 'dart:io';

final Map<String, dynamic> _activeSessions = HashMap();
final Map<String, dynamic> _rooms = HashMap();

class SessionInfo {
  final String sessionId;
  final WebSocket websocket;
  String? activeRoom;
  String? previousRoom;

  SessionInfo({
    required this.sessionId,
    required this.websocket,
    this.activeRoom,
    this.previousRoom,
  });
}

class WebsocketSession {
  static final WebsocketSession _singleton = WebsocketSession._internal();
  factory WebsocketSession() {
    return _singleton;
  }
  WebsocketSession._internal();

  /// add new websocket session to the active sessions
  void addNewSession(String sessionId, WebSocket ws) {
    _activeSessions.addAll({
      sessionId: SessionInfo(
        sessionId: sessionId,
        websocket: ws,
      )
    });
  }

  /// get session of connected socket
  SessionInfo? getWebSocketInfo(String sessionId) {
    return _activeSessions[sessionId];
  }

 /// remove session of connected socket
  void removeSession(String sessionId) {
    SessionInfo? info = _activeSessions[sessionId];
    if(info != null && info.activeRoom != null){
       _activeSessions.remove(sessionId);
       leaveRoom(sessionId, info.activeRoom);
       info.websocket.close();
    }
  }

 
  void joinRoom(String sessionId, String roomId) {
    if(_rooms[roomId] == null){
      _rooms.addAll({roomId:<String>[]});
    }
    _rooms[roomId]?.add(sessionId);

    SessionInfo? info = _activeSessions[sessionId];
    if(info != null){
      if(info.previousRoom != null){
       leaveRoom(sessionId, info.previousRoom);
      }
      info.activeRoom = roomId;
      info.activeRoom = roomId;
    }
  }

  void leaveRoom(String sessionId, String? roomId) {
    if(_rooms[roomId] == null && roomId != null){
      SessionInfo? info = _activeSessions[sessionId];
    if(info != null){
      info.previousRoom = null;
      info.activeRoom = null;
      _rooms[roomId]?.remove(sessionId);
    }
    }
  }

  /// get all room members (socket ids)
  /// for send message to a room
  List<String> getRoomMembers(String roomId) {
    return _rooms[roomId] ?? <String>[];
  }


}
