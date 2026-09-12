import 'package:vania/service_provider.dart';
import 'package:vania_websocket/vania_websocket.dart';
import 'package:websocket_chat/chat/chat_hub.dart';

/// Wires the transport-free [ChatHub] onto the WebSocket service:
/// connection lifecycle drives connect/disconnect, and each client event
/// maps to one hub call.
///
/// Client → server events: `set-name`, `create-room`, `join`, `leave`,
/// `message`, `typing`. (The built-in `join-room`/`leave-room` names are
/// intercepted by the service, so this sample uses `join`/`leave`.)
class ChatServiceProvider extends ServiceProvider {
  @override
  Future<void> register() async {}

  @override
  Future<void> boot() async {
    final ws = VaniaWebSocketService();
    final hub = ChatHub((sessionId, event, payload) =>
        ws.sendTo(sessionId, event, payload));

    ws.onConnectionChanged.listen((event) {
      switch (event.type) {
        case WebSocketConnectionEventType.connected:
          hub.connect(event.sessionId);
        case WebSocketConnectionEventType.disconnected:
          hub.disconnect(event.sessionId);
      }
    });

    String sid(Map<String, dynamic> ctx) => ctx['session_id'] as String;
    String room(dynamic p) => (p as Map)['room'] as String;

    ws.on('set-name', (p, s, c) async => hub.setName(sid(c), (p as Map)['name'] as String));
    ws.on('create-room', (p, s, c) async => hub.createRoom(sid(c), room(p)));
    ws.on('join', (p, s, c) async => hub.join(sid(c), room(p)));
    ws.on('leave', (p, s, c) async => hub.leave(sid(c), room(p)));
    ws.on('message', (p, s, c) async => hub.message(sid(c), room(p), (p as Map)['text'] as String));
    ws.on('typing', (p, s, c) async => hub.typing(sid(c), room(p)));
  }
}
