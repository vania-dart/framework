import 'dart:collection';
import 'dart:io';

final Map<String, dynamic> _activeSessions = HashMap();
final Map<String, dynamic> _rooms = HashMap();

class SessionInfo {
  final String socketId;
  final WebSocket websocket;
  String? activeRoom;
  String? previousRoom;

  SessionInfo({
    required this.socketId,
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
  void addNewSession(String socketId, WebSocket ws) {
    _activeSessions.addAll({
      socketId: SessionInfo(
        socketId: socketId,
        websocket: ws,
      )
    });
  }

  /// get session of connected socket
  SessionInfo? getWebSocketInfo(String socketId) {
    return _activeSessions[socketId];
  }

 /// remove session of connected socket
  void removeSession(String socketId) {
    SessionInfo? info = _activeSessions[socketId];
    if(info != null && info.activeRoom != null){
       _activeSessions.remove(socketId);
       leaveRoom(socketId, info.activeRoom);
       info.websocket.close();
    }
  }

 
  void joinRoom(String socketId, String roomId) {
    if(_rooms[roomId] == null){
      _rooms.addAll({roomId:<String>[]});
    }
    _rooms[roomId]?.add(socketId);

    SessionInfo? info = _activeSessions[socketId];
    if(info != null){
      if(info.previousRoom != null){
       leaveRoom(socketId, info.previousRoom);
      }
      info.activeRoom = roomId;
      info.activeRoom = roomId;
    }
  }

  void leaveRoom(String socketId, String? roomId) {
    if(_rooms[roomId] == null && roomId != null){
      SessionInfo? info = _activeSessions[socketId];
    if(info != null){
      info.previousRoom = null;
      info.activeRoom = null;
      _rooms[roomId]?.remove(socketId);
    }
    }
  }

  /// get all room members (socket ids)
  /// for send message to a room
  List<String> getRoomMembers(String roomId) {
    return _rooms[roomId] ?? <String>[];
  }


}
