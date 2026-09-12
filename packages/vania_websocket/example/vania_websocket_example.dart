import 'package:vania_websocket/vania_websocket.dart';

void main() {
  final service = VaniaWebSocketService()
    ..init(
      config: WebSocketConfig(
        enablePresence: true,
        enableRateLimit: true,
        rateLimitMax: 100,
        rateLimitWindow: const Duration(minutes: 1),
      ),
    );

  service.on('chat-message', (payload, socket, context) async {
    service.emitToRoom(payload['room'] as String, 'chat-message', {
      'sender': context['session_id'],
      'text': payload['text'],
    });
  });
}
