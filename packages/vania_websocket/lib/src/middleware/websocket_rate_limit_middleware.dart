import 'dart:io';

import 'package:vania/http/middleware.dart';

import '../services/websocket_rate_limiter.dart';

class WebSocketRateLimitMiddleware extends WebSocketMiddleware {
  WebSocketRateLimitMiddleware({
    required this.maxRequests,
    required this.window,
  });

  final int maxRequests;
  final Duration window;

  final Map<String, WebSocketRateLimiter> _limiters = {};

  WebSocketRateLimiter _getLimiter(String key) {
    _limiters.putIfAbsent(
      key,
      () => WebSocketRateLimiter(maxRequests: maxRequests, window: window),
    );
    return _limiters[key]!;
  }

  @override
  Future<void> handle(HttpRequest req) async {
    // Get client identifier (IP or user ID)
    final clientKey = _getClientKey(req);
    final limiter = _getLimiter(clientKey);

    if (!limiter.isAllowed(clientKey)) {
      final info = limiter.getInfo(clientKey);
      throw WebSocketRateLimitException(
        'Rate limit exceeded. Remaining: ${info.remaining}',
        limit: info.limit,
        remaining: info.remaining,
        reset: info.reset,
      );
    }
  }

  String _getClientKey(HttpRequest req) {
    // Try to get user ID from token first
    final token =
        req.uri.queryParameters['token'] ??
        req.headers.value('authorization')?.replaceFirst('Bearer ', '');

    if (token != null && token.isNotEmpty) {
      return 'token:$token';
    }

    // Fall back to IP address
    return 'ip:${req.connectionInfo?.remoteAddress.address ?? 'unknown'}';
  }

  /// Get rate limit info for a client
  RateLimitInfo getInfo(String clientKey) {
    return _getLimiter(clientKey).getInfo(clientKey);
  }

  /// Reset rate limit for a client
  void reset(String clientKey) {
    _getLimiter(clientKey).reset(clientKey);
  }

  /// Clean up old entries
  void cleanup() {
    for (final limiter in _limiters.values) {
      limiter.cleanup();
    }
  }
}

class WebSocketRateLimitException implements Exception {
  final String message;
  final int limit;
  final int remaining;
  final DateTime? reset;

  WebSocketRateLimitException(
    this.message, {
    required this.limit,
    required this.remaining,
    this.reset,
  });

  @override
  String toString() => 'WebSocketRateLimitException: $message';
}
