import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../channel/websocket_channel_manager.dart';
import '../config/websocket_config.dart';
import '../middleware/websocket_rate_limit_middleware.dart';
import 'websocket_event_handler.dart';
import 'websocket_presence.dart';

class VaniaWebSocketService {
  static final VaniaWebSocketService _singleton = VaniaWebSocketService._();
  factory VaniaWebSocketService() => _singleton;
  VaniaWebSocketService._();

  final Map<String, WebSocket> _connections = {};
  final Map<String, Map<String, dynamic>> _connectionData = {};
  final Map<String, Set<String>> _rooms = {};
  final Map<String, Set<String>> _sessionRooms = {};
  final StreamController<WebSocketConnectionEvent> _connectionController =
      StreamController<WebSocketConnectionEvent>.broadcast();

  WebSocketConfig? _config;
  WebSocketChannelManager? _channelManager;
  WebSocketPresence? _presence;
  WebSocketEventHandler? _eventHandler;
  WebSocketRateLimitMiddleware? _rateLimiter;
  int _sessionCounter = 0;
  final Random _random = Random.secure();

  Stream<WebSocketConnectionEvent> get onConnectionChanged =>
      _connectionController.stream;

  int get connectionCount => _connections.length;

  bool get isEmpty => _connections.isEmpty;

  List<String> get connectionIds => _connections.keys.toList();

  List<String> get roomIds => _rooms.keys.toList();

  /// Initialize the WebSocket service
  void init({WebSocketConfig? config}) {
    _config = config ?? WebSocketConfig.fromApplication();
    _channelManager = WebSocketChannelManager();
    _presence = _config!.enablePresence ? WebSocketPresence() : null;
    _eventHandler = WebSocketEventHandler();
    _rateLimiter = _config!.enableRateLimit
        ? WebSocketRateLimitMiddleware(
            maxRequests: _config!.rateLimitMax,
            window: _config!.rateLimitWindow,
          )
        : null;
  }

  /// Register event handlers
  void on(String event, WebSocketEventHandlerCallback handler) {
    _eventHandler?.on(event, handler);
  }

  /// Register event middleware
  void middleware(String event, WebSocketEventHandlerMiddleware middleware) {
    _eventHandler?.middleware(event, middleware);
  }

  /// Handle WebSocket upgrade
  Future<void> handle(HttpRequest req) async {
    if (_config == null) {
      init();
    }

    final routePath = req.uri.path.replaceFirst('/', '');

    // Check connection limit
    if (_connections.length >= (_config?.maxConnections ?? 1000)) {
      _sendError(req, 'Connection limit reached');
      return;
    }

    try {
      // Run rate limiting if enabled
      if (_rateLimiter != null) {
        await _rateLimiter!.handle(req);
      }

      // Upgrade to WebSocket
      final socket = await WebSocketTransformer.upgrade(req);
      final sessionId = _nextSessionId();

      // Store connection
      _connections[sessionId] = socket;
      _connectionData[sessionId] = {
        'route': routePath,
        'connected_at': DateTime.now().toIso8601String(),
      };

      _presence?.connectRememberedUser(
        req,
        sessionId: sessionId,
        websocket: socket,
      );

      // Send connected event
      _emit(socket, 'connected', {'session_id': sessionId});

      // Notify connection
      _connectionController.add(
        WebSocketConnectionEvent(
          type: WebSocketConnectionEventType.connected,
          sessionId: sessionId,
        ),
      );

      // Listen for messages
      socket.listen(
        (data) async {
          try {
            final payload = _decodeIncomingMessage(data);
            final event = payload['event'] as String?;
            final messagePayload = payload['payload'];

            if (event != null) {
              // Handle built-in events
              if (_handleBuiltinEvent(
                event,
                messagePayload,
                sessionId,
                socket,
                routePath,
              )) {
                return;
              }

              // Handle custom events
              final context = {
                'session_id': sessionId,
                'route': routePath,
                'data': _connectionData[sessionId] ?? {},
              };

              await _eventHandler?.handle(
                event,
                messagePayload,
                socket,
                context,
              );
            }
          } catch (e) {
            _emitError(socket, 'Invalid message format: $e');
          }
        },
        onDone: () {
          _handleDisconnect(sessionId, routePath);
        },
        onError: (error) {
          _handleDisconnect(sessionId, routePath);
        },
      );
    } catch (e) {
      _sendError(req, 'WebSocket upgrade failed: $e');
    }
  }

  /// Handle built-in events
  bool _handleBuiltinEvent(
    String event,
    dynamic payload,
    String sessionId,
    WebSocket socket,
    String routePath,
  ) {
    final payloadMap = payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
    switch (event) {
      case 'join-room':
        final roomId = payloadMap['room'] as String?;
        if (roomId != null && roomId.isNotEmpty) {
          _joinRoom(sessionId, routePath, roomId, socket);
        }
        return true;

      case 'leave-room':
        final roomId = payloadMap['room'] as String?;
        if (roomId != null && roomId.isNotEmpty) {
          _leaveRoom(sessionId, routePath, roomId, socket);
        }
        return true;

      case 'join-channel':
        final channelId = payloadMap['channel'] as String?;
        if (channelId != null && channelId.isNotEmpty) {
          _joinChannel(channelId, sessionId, socket, payloadMap['data']);
        }
        return true;

      case 'leave-channel':
        final channelId = payloadMap['channel'] as String?;
        if (channelId != null && channelId.isNotEmpty) {
          _leaveChannel(channelId, sessionId);
        }
        return true;

      case 'ping':
        _emit(socket, 'pong', {});
        return true;

      case 'set-data':
        _setConnectionData(sessionId, payloadMap);
        return true;

      default:
        return false;
    }
  }

  /// Handle disconnect
  void _handleDisconnect(String sessionId, String routePath) {
    // Remove from connections
    _connections.remove(sessionId);
    _connectionData.remove(sessionId);

    // Leave all rooms
    _leaveAllRooms(sessionId, routePath);

    // Leave all channels
    _channelManager?.leaveAllChannels(sessionId);

    // Remove from presence
    _presence?.userDisconnectedSession(sessionId);

    // Notify disconnection
    _connectionController.add(
      WebSocketConnectionEvent(
        type: WebSocketConnectionEventType.disconnected,
        sessionId: sessionId,
      ),
    );
  }

  /// Join a room
  void _joinRoom(
    String sessionId,
    String routePath,
    String roomId,
    WebSocket socket,
  ) {
    final fullRoomId = '${routePath}_$roomId';
    final currentRooms = _sessionRooms[sessionId] ?? <String>{};
    if (currentRooms.length >= (_config?.maxRoomsPerClient ?? 10) &&
        !currentRooms.contains(fullRoomId)) {
      _emitError(socket, 'Maximum rooms per connection reached');
      return;
    }

    final members = _rooms.putIfAbsent(fullRoomId, () => <String>{});
    final added = members.add(sessionId);
    _sessionRooms.putIfAbsent(sessionId, () => <String>{}).add(fullRoomId);

    _emit(socket, 'joined-room', {'room': roomId});

    if (!added) return;

    // Emit to others in room
    _emitToRoom(fullRoomId, 'user-joined', {
      'session_id': sessionId,
      'room': roomId,
    }, excludeSessionId: sessionId);
  }

  /// Leave a room
  void _leaveRoom(
    String sessionId,
    String routePath,
    String roomId,
    WebSocket socket,
  ) {
    final fullRoomId = '${routePath}_$roomId';

    _emit(socket, 'left-room', {'room': roomId});

    _removeRoomMember(fullRoomId, sessionId);

    _emitToRoom(fullRoomId, 'user-left', {
      'session_id': sessionId,
      'room': roomId,
    }, excludeSessionId: sessionId);
  }

  /// Leave all rooms
  void _leaveAllRooms(String sessionId, String routePath) {
    final rooms = List<String>.from(_sessionRooms[sessionId] ?? const []);
    for (final roomId in rooms) {
      _removeRoomMember(roomId, sessionId);
      _emitToRoom(roomId, 'user-left', {
        'session_id': sessionId,
        'room': _publicRoomName(routePath, roomId),
      }, excludeSessionId: sessionId);
    }
  }

  /// Join a channel
  void _joinChannel(
    String channelId,
    String sessionId,
    WebSocket socket,
    dynamic data,
  ) {
    _channelManager?.joinChannel(channelId, sessionId, socket, data: data);

    _emit(socket, 'joined-channel', {'channel': channelId});

    // Notify others in channel
    _channelManager?.emitToChannel(channelId, 'user-joined-channel', {
      'session_id': sessionId,
      'channel': channelId,
    }, excludeSessionId: sessionId);
  }

  /// Leave a channel
  void _leaveChannel(String channelId, String sessionId) {
    _channelManager?.leaveChannel(channelId, sessionId);
  }

  /// Set connection data
  void _setConnectionData(String sessionId, Map<String, dynamic> data) {
    _connectionData[sessionId]?.addAll(data);
  }

  /// Send to specific connection
  void sendTo(String sessionId, String event, dynamic payload) {
    final socket = _connections[sessionId];
    if (socket != null) {
      _emit(socket, event, payload);
    }
  }

  /// Broadcast to all connections
  void broadcast(String event, dynamic payload, {String? excludeSessionId}) {
    for (final entry in _connections.entries) {
      if (excludeSessionId != null && entry.key == excludeSessionId) {
        continue;
      }
      _emit(entry.value, event, payload);
    }
  }

  /// Send to room
  void emitToRoom(
    String roomId,
    String event,
    dynamic payload, {
    String? excludeSessionId,
  }) {
    _emitToRoom(roomId, event, payload, excludeSessionId: excludeSessionId);
  }

  List<String> getRoomMembers(String roomId) {
    return _resolveRoomMembers(roomId).toList();
  }

  /// Send to channel
  void emitToChannel(
    String channelId,
    String event,
    dynamic payload, {
    String? excludeSessionId,
  }) {
    _channelManager?.emitToChannel(
      channelId,
      event,
      payload,
      excludeSessionId: excludeSessionId,
    );
  }

  /// Get connection info
  Map<String, dynamic>? getConnectionInfo(String sessionId) {
    return _connectionData[sessionId];
  }

  /// Get all connections info
  List<Map<String, dynamic>> getAllConnectionsInfo() {
    return _connectionData.entries
        .map((entry) => {'session_id': entry.key, ...entry.value})
        .toList();
  }

  /// Check if connection exists
  bool hasConnection(String sessionId) {
    return _connections.containsKey(sessionId);
  }

  /// Close a specific connection
  void close(String sessionId, [String reason = 'Closed by server']) {
    final socket = _connections.remove(sessionId);
    if (socket != null) {
      socket.close(1000, reason);
      _handleDisconnect(sessionId, _connectionData[sessionId]?['route'] ?? '');
    }
  }

  /// Close all connections
  void closeAll([String reason = 'Server shutting down']) {
    for (final entry in _connections.entries) {
      try {
        entry.value.close(1000, reason);
      } catch (_) {
        // Already closed
      }
    }
    _connections.clear();
    _connectionData.clear();
    _rooms.clear();
    _sessionRooms.clear();
  }

  void _emit(WebSocket socket, String event, dynamic payload) {
    try {
      socket.add(jsonEncode({'event': event, 'payload': payload}));
    } catch (_) {
      // Connection might be closed
    }
  }

  void _emitToRoom(
    String roomId,
    String event,
    dynamic payload, {
    String? excludeSessionId,
  }) {
    final members = _resolveRoomMembers(roomId);
    for (final memberId in members) {
      if (excludeSessionId != null && memberId == excludeSessionId) {
        continue;
      }
      sendTo(memberId, event, payload);
    }
  }

  Set<String> _resolveRoomMembers(String roomId) {
    final exactMembers = _rooms[roomId];
    if (exactMembers != null) return Set<String>.from(exactMembers);

    final members = <String>{};
    for (final entry in _rooms.entries) {
      if (entry.key.endsWith('_$roomId')) {
        members.addAll(entry.value);
      }
    }
    return members;
  }

  void _removeRoomMember(String roomId, String sessionId) {
    final members = _rooms[roomId];
    if (members != null) {
      members.remove(sessionId);
      if (members.isEmpty) _rooms.remove(roomId);
    }

    final sessionRooms = _sessionRooms[sessionId];
    if (sessionRooms != null) {
      sessionRooms.remove(roomId);
      if (sessionRooms.isEmpty) _sessionRooms.remove(sessionId);
    }
  }

  String _publicRoomName(String routePath, String roomId) {
    final prefix = '${routePath}_';
    if (!roomId.startsWith(prefix)) return roomId;
    return roomId.substring(prefix.length);
  }

  void _emitError(WebSocket socket, String message) {
    _emit(socket, 'error', {'message': message});
  }

  void _sendError(HttpRequest req, String message) {
    // WebSocket upgrade errors can't be sent as regular HTTP responses
    // after the upgrade attempt begins
    try {
      req.response.statusCode = HttpStatus.badRequest;
      req.response.close();
    } catch (_) {
      // Ignore
    }
  }

  Map<String, dynamic> _decodeIncomingMessage(dynamic data) {
    if (data is! String) {
      throw const FormatException('Message must be a JSON string');
    }
    final decoded = jsonDecode(data);
    if (decoded is! Map) {
      throw const FormatException('Message must be a JSON object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _nextSessionId() {
    _sessionCounter += 1;
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = _random.nextInt(1 << 32).toRadixString(36);
    return 'ws:$timestamp:${_sessionCounter.toRadixString(36)}:$random';
  }

  void dispose() {
    closeAll();
    _connectionController.close();
    _presence?.dispose();
  }
}

class WebSocketConnectionEvent {
  final WebSocketConnectionEventType type;
  final String sessionId;
  final String? error;

  WebSocketConnectionEvent({
    required this.type,
    required this.sessionId,
    this.error,
  });
}

enum WebSocketConnectionEventType { connected, disconnected }
