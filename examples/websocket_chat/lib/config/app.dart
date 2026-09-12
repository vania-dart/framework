import 'package:vania/vania.dart';
import 'package:vania/service_provider.dart';
import 'package:vania_websocket/vania_websocket.dart';
import 'package:websocket_chat/chat/chat_service_provider.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'websocket_chat'),
  'url': env('APP_URL', 'http://localhost'),
  'providers': <ServiceProvider>[
    WebSocketServiceProvider(),
    ChatServiceProvider(),
  ],
};
