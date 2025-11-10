import 'dart:convert';
import 'dart:io';
import 'package:uuid/v8.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/middleware/web_socket_middleware_handler.dart';
import 'websocket_client.dart';
import 'websocket_constants.dart';
import 'websocket_event.dart';
import 'websocket_session.dart';

class WebSocketHandler implements WebSocketEvent {
  final WebsocketSession _session = WebsocketSession();

  static final WebSocketHandler _singleton = WebSocketHandler._internal();
  factory WebSocketHandler() => _singleton;
  WebSocketHandler._internal();

  final Map<String, List<WebSocketMiddleware>?> _middleware = {};

  late String _websocketRoute;
  WebSocketHandler websocketRoute(
    String path, {
    List<WebSocketMiddleware>? middleware,
  }) {
    _websocketRoute = path.replaceFirst('/', '');

    _middleware[_websocketRoute] = middleware;

    return this;
  }

  final Map<String, dynamic> _events = {};

  Future handler(HttpRequest req) async {
    String routePath = req.uri.path.replaceFirst('/', '');

    WebSocket websocket = await WebSocketTransformer.upgrade(req);

    String sessionId = 'ws:${UuidV8().generate()}';

    _session.addNewSession(sessionId, websocket);

    final WebSocketClientImpl client = WebSocketClientImpl(
      session: _session,
      id: sessionId,
      routePath: routePath,
    );

    websocket.add(
      jsonEncode({
        'event': 'connected',
        'payload': {'session_id': sessionId},
      }),
    );

    try {
      if (_middleware[_websocketRoute] != null) {
        await webSocketMiddlewareHandler(
          _middleware[_websocketRoute] as List<WebSocketMiddleware>,
          req,
        );
      }
    } on WebSocketException catch (e) {
      websocket.add(
        jsonEncode({
          'event': 'error',
          'payload': {'message': e.message},
        }),
      );
      return;
    }

    Function? openFunction = _events['${routePath}_connect'];
    if (openFunction != null) {
      Function.apply(openFunction, <dynamic>[client]);
    }

    websocket.listen(
      (data) async {
        Map<String, dynamic> payload = jsonDecode(data);
        String event = '${routePath}_${payload[webScoketEventKey]}';

        /// client join the room
        if (event == '${routePath}_$webSocketJoinRoomEventName') {
          String? roomId = payload[webSocketRoomKey].toString();
          if (roomId.isNotEmpty) {
            _session.joinRoom(sessionId, '${routePath}_$roomId');
          }
          return;
        }

        /// client left the room
        if (event == webSocketLeftRoomEventName) {
          String? roomId = payload[webSocketRoomKey].toString();
          if (roomId.isNotEmpty) {
            _session.leftRoom(sessionId, '${routePath}_$roomId');
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
      },
      onDone: () {
        Function? openFunction = _events['${routePath}_disconnect'];
        if (openFunction != null) {
          Function.apply(openFunction, <dynamic>[client]);
        }

        _session.removeSession(sessionId);
      },
      onError: (_) {
        Function? openFunction = _events['${routePath}_error'];
        if (openFunction != null) {
          Function.apply(openFunction, <dynamic>[client]);
        }

        _session.removeSession(sessionId);
      },
    );
  }

  ///  Listener
  /// ```
  /// event.on('event',function(WebSocketClient client,message){
  ///   response
  ///  });
  /// ```
  @override
  void on(String event, Function function) {
    _events['${_websocketRoute}_$event'] = function;
  }
}
