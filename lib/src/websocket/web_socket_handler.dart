import 'dart:convert';
import 'dart:io';
import 'package:uuid/v4.dart';
import 'websocket_client.dart';
import 'websocket_constants.dart';
import 'websocket_event.dart';
import 'websocket_session.dart';

class WebSocketHandler implements WebSocketEvent {
  final WebsocketSession _session = WebsocketSession();

  static final WebSocketHandler _singleton = WebSocketHandler._internal();
  factory WebSocketHandler() => _singleton;
  WebSocketHandler._internal();

  late String _webSocketPath;
  WebSocketHandler webSocketPath(String path)  {
    _webSocketPath = path.replaceFirst('/', '');
    return this;
  }

  final Map<String, dynamic> _events = {};

  Future handler(HttpRequest req) async {
    String _path = req.uri.path.replaceFirst('/', '');
    WebSocket websocket = await WebSocketTransformer.upgrade(req);

    String sessionId = 'ws:${UuidV4().generate()}';

    _session.addNewSession(sessionId, websocket);

    final WebSocketClientImpl client = WebSocketClientImpl(
      session: _session,
      id: sessionId,
    );

    websocket.listen((data) {
      Map<String, dynamic> payload = jsonDecode(data);
      print('${_path}_${payload[webScoketEventKey]}');
      String event = '${_path}_${payload[webScoketEventKey]}';

      /// client join the room
      if (event == webSocketJoinRoomEventName) {
        String? roomId = payload[webSocketRoomKey];
        if (roomId != null) {
          _session.joinRoom(sessionId, roomId);
          client.joinRoom(roomId);
        }
        return;
      }

      /// client left the room
      if (event == webSocketLeftRoomEventName) {
        String? roomId = payload[webSocketRoomKey];
        if (roomId != null) {
          _session.leftRoom(sessionId, roomId);
          client.leftRoom(roomId);
        }
        return;
      }

      /// websocket response
      /// ```
      /// event.on('event',function(WebSocketClient client,message){
      ///   response
      ///  });
      /// ```
      dynamic message = payload[webSocketMessageKey];

      Function? controller = _events[event];

      if (controller == null) {
        return;
      }
      Function.apply(controller, <dynamic>[client, message]);
    }, onDone: () {
      _session.removeSession(sessionId);
    }, onError: (error) {
      _session.removeSession(sessionId);
    });
  }

  ///  Listener
  /// ```
  /// event.on('event',function(WebSocketClient client,message){
  ///   response
  ///  });
  /// ```
  @override
  void on(String event, Function function) {
    print('${_webSocketPath}_$event');
    _events['${_webSocketPath}_$event'] = function;
  }
}
