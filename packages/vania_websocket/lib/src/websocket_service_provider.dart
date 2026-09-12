import 'package:vania/service_provider.dart';
import 'package:vania/websocket.dart' show WebSocketUpgradeDispatcher;

import 'config/websocket_config.dart';
import 'services/vania_websocket_service.dart';

/// Boots the rich WebSocket surface (channels, rooms, presence,
/// rate-limiting) and routes every WS upgrade on the app's single HTTP
/// port through [VaniaWebSocketService].
///
/// The app declares this provider in `config.providers`. During
/// [Application.initialize] the provider's [register] initializes the
/// service, and [boot] hands the upgrade dispatcher an override so
/// core's [RequestHandler] delegates every WS upgrade to us — same
/// `APP_HOST`/`APP_PORT` as the HTTP server, no second listener.
class WebSocketServiceProvider extends ServiceProvider {
  WebSocketServiceProvider({this.config});

  final WebSocketConfig? config;

  @override
  Future<void> register() async {
    final resolvedConfig = config ?? WebSocketConfig.fromApplication();
    VaniaWebSocketService().init(config: resolvedConfig);
  }

  @override
  Future<void> boot() async {
    final resolvedConfig = config ?? WebSocketConfig.fromApplication();
    if (!resolvedConfig.enabled) {
      WebSocketUpgradeDispatcher().reset();
      return;
    }
    WebSocketUpgradeDispatcher().override(VaniaWebSocketService().handle);
  }
}

/// Legacy shim retained for older docs that referenced a separate
/// registrar. New code should just use [WebSocketServiceProvider].
class WebSocketRouteRegistrar {
  static void register({WebSocketConfig? config}) {
    final resolvedConfig = config ?? WebSocketConfig.fromApplication();
    if (!resolvedConfig.enabled) {
      WebSocketUpgradeDispatcher().reset();
      return;
    }
    VaniaWebSocketService().init(config: resolvedConfig);
    WebSocketUpgradeDispatcher().override(VaniaWebSocketService().handle);
  }
}
