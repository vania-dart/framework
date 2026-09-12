import 'package:vania/vania.dart';

class WebSocketConfig {
  WebSocketConfig({
    this.enabled = true,
    this.path = 'ws',
    this.pingInterval = const Duration(seconds: 30),
    this.timeout = const Duration(seconds: 60),
    this.maxConnections = 1000,
    this.maxRoomsPerClient = 10,
    this.enablePresence = true,
    this.enableRateLimit = false,
    this.rateLimitMax = 100,
    this.rateLimitWindow = const Duration(minutes: 1),
  });

  final bool enabled;
  final String path;
  final Duration pingInterval;
  final Duration timeout;
  final int maxConnections;
  final int maxRoomsPerClient;
  final bool enablePresence;
  final bool enableRateLimit;
  final int rateLimitMax;
  final Duration rateLimitWindow;

  factory WebSocketConfig.fromEnv() {
    return WebSocketConfig(
      enabled: env<bool>('WEBSOCKET_ENABLED', true),
      path: env<String>('WEBSOCKET_PATH', 'ws'),
      pingInterval: Duration(seconds: env<int>('WEBSOCKET_PING_INTERVAL', 30)),
      timeout: Duration(seconds: env<int>('WEBSOCKET_TIMEOUT', 60)),
      maxConnections: env<int>('WEBSOCKET_MAX_CONNECTIONS', 1000),
      maxRoomsPerClient: env<int>('WEBSOCKET_MAX_ROOMS', 10),
      enablePresence: env<bool>('WEBSOCKET_PRESENCE', true),
      enableRateLimit: env<bool>('WEBSOCKET_RATE_LIMIT', false),
      rateLimitMax: env<int>('WEBSOCKET_RATE_LIMIT_MAX', 100),
      rateLimitWindow: Duration(
        seconds: env<int>('WEBSOCKET_RATE_LIMIT_WINDOW', 60),
      ),
    );
  }

  factory WebSocketConfig.fromApplication() {
    final config = Config().get('websocket');
    if (config is Map<String, dynamic>) {
      return WebSocketConfig(
        enabled: config['enabled'] ?? true,
        path: config['path'] ?? 'ws',
        pingInterval: Duration(seconds: config['ping_interval'] ?? 30),
        timeout: Duration(seconds: config['timeout'] ?? 60),
        maxConnections: config['max_connections'] ?? 1000,
        maxRoomsPerClient: config['max_rooms'] ?? 10,
        enablePresence: config['presence'] ?? true,
        enableRateLimit: config['rate_limit'] ?? false,
        rateLimitMax: config['rate_limit_max'] ?? 100,
        rateLimitWindow: Duration(seconds: config['rate_limit_window'] ?? 60),
      );
    }
    return WebSocketConfig.fromEnv();
  }
}
