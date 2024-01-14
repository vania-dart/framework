import 'dart:convert';
import 'dart:io';
import 'package:uuid/v4.dart';

import 'websocket_session.dart';

const String WEB_SOCKET_JOIN_ROOM_EVENT_NAME = 'joinRoom';

const String WEB_SOCKET_EVENT_KEY = 'event';

const String WEB_SOCKET_MESSAGE_KEY = 'message';

const String WEB_SOCKET_SENDER_KEY = 'sender';

const String WEB_SOCKET_ROOM_KEY = 'room';

class WebSocketHandler{

WebsocketSession _session = WebsocketSession();

Future handler(HttpRequest req) async {
  WebSocket websocket = await WebSocketTransformer.upgrade(req);

  String id = 'ws:${UuidV4()}';

  websocket.listen((data) {
    Map<String, dynamic> payload = jsonDecode(data);
    String event = payload[WEB_SOCKET_EVENT_KEY];
    dynamic message = payload[WEB_SOCKET_MESSAGE_KEY];

    if(event == WEB_SOCKET_JOIN_ROOM_EVENT_NAME){
      String room = payload[WEB_SOCKET_ROOM_KEY];
      v.joinRoom(id, room);
    }

  }, onDone: () {}, onError: (error) {});
}
}


