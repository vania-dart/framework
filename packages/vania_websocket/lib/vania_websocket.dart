/// WebSocket extension for Vania framework.
///
/// Provides channels, rooms, presence tracking, broadcasting,
/// and event handling for real-time applications.
library;

// Config
export 'src/config/websocket_config.dart';

// Channel
export 'src/channel/websocket_channel.dart';
export 'src/channel/websocket_channel_manager.dart';

// Middleware
export 'src/middleware/websocket_auth_middleware.dart';
export 'src/middleware/websocket_rate_limit_middleware.dart';

// Services
export 'src/services/vania_websocket_service.dart';
export 'src/services/websocket_event_handler.dart';
export 'src/services/websocket_presence.dart';
export 'src/services/websocket_rate_limiter.dart';

// Provider
export 'src/websocket_service_provider.dart';
