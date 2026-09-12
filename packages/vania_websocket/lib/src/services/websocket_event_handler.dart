import 'dart:convert';
import 'dart:io';

class WebSocketEventHandler {
  final Map<String, WebSocketEventHandlerCallback> _handlers = {};
  final Map<String, List<WebSocketEventHandlerMiddleware>> _middlewares = {};

  /// Register an event handler
  void on(String event, WebSocketEventHandlerCallback handler) {
    _handlers[event] = handler;
  }

  /// Register middleware for a specific event
  void middleware(String event, WebSocketEventHandlerMiddleware middleware) {
    _middlewares.putIfAbsent(event, () => []);
    _middlewares[event]!.add(middleware);
  }

  /// Handle an incoming message
  Future<bool> handle(
    String event,
    dynamic payload,
    WebSocket socket,
    Map<String, dynamic> context,
  ) async {
    final handler = _handlers[event];
    if (handler == null) {
      return false;
    }

    // Run event-specific middleware
    final middlewares = _middlewares[event] ?? [];
    for (final middleware in middlewares) {
      final shouldContinue = await middleware(payload, socket, context);
      if (!shouldContinue) {
        return false;
      }
    }

    // Execute the handler
    await handler(payload, socket, context);
    return true;
  }

  /// Check if an event handler exists
  bool hasHandler(String event) {
    return _handlers.containsKey(event);
  }

  /// Remove an event handler
  void off(String event) {
    _handlers.remove(event);
    _middlewares.remove(event);
  }

  /// Get all registered event names
  List<String> get registeredEvents => _handlers.keys.toList();

  /// Clear all handlers
  void clear() {
    _handlers.clear();
    _middlewares.clear();
  }
}

typedef WebSocketEventHandlerCallback =
    Future<void> Function(
      dynamic payload,
      WebSocket socket,
      Map<String, dynamic> context,
    );

typedef WebSocketEventHandlerMiddleware =
    Future<bool> Function(
      dynamic payload,
      WebSocket socket,
      Map<String, dynamic> context,
    );

/// Typed event builder for type-safe event handling
class WebSocketTypedEvent<T> {
  final String event;
  final Future<void> Function(
    T data,
    WebSocket socket,
    Map<String, dynamic> context,
  )
  handler;

  WebSocketTypedEvent({required this.event, required this.handler});

  /// Convert to raw handler
  WebSocketEventHandlerCallback toHandler() {
    return (
      dynamic payload,
      WebSocket socket,
      Map<String, dynamic> context,
    ) async {
      final typedData = _parsePayload(payload);
      await handler(typedData, socket, context);
    };
  }

  T _parsePayload(dynamic payload) {
    if (payload is T) {
      return payload;
    }
    if (payload is String) {
      try {
        final decoded = jsonDecode(payload);
        return decoded as T;
      } catch (_) {
        throw FormatException('Cannot parse payload as $T');
      }
    }
    if (payload is Map) {
      return payload as T;
    }
    throw FormatException('Cannot parse payload as $T');
  }
}

/// Event emitter helper
class WebSocketEventEmitter {
  static void emit(WebSocket socket, String event, dynamic payload) {
    try {
      socket.add(jsonEncode({'event': event, 'payload': payload}));
    } catch (_) {
      // Connection might be closed
    }
  }

  static void emitError(WebSocket socket, String message) {
    emit(socket, 'error', {'message': message});
  }

  static void emitConnected(WebSocket socket, String sessionId) {
    emit(socket, 'connected', {'session_id': sessionId});
  }

  static void emitDisconnected(WebSocket socket) {
    emit(socket, 'disconnected', {});
  }
}
