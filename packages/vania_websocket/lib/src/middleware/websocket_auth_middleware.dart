import 'dart:io';

import 'package:vania/http/middleware.dart';
import 'package:vania_auth/vania_auth.dart';

import '../services/websocket_presence.dart';

class WebSocketAuthMiddleware extends WebSocketMiddleware {
  WebSocketAuthMiddleware({this.guard});

  final String? guard;

  @override
  Future<void> handle(HttpRequest req) async {
    // Extract token from query parameters or headers
    String? token = req.uri.queryParameters['token'];

    if (token == null || token.isEmpty) {
      // Try to get from Authorization header
      final authHeader = req.headers.value('authorization');
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        token = authHeader.substring(7);
      }
    }

    if (token == null || token.isEmpty) {
      throw WebSocketException('Authentication required');
    }

    try {
      // Verify the token
      final auth = Auth();
      if (guard != null) {
        auth.guard(guard!);
      }

      await auth.check(token);

      if (!auth.loggedIn) {
        throw WebSocketException('Invalid token');
      }

      WebSocketPresence().rememberAuthenticatedUser(
        req,
        userId: auth.id?.toString(),
        data: auth.currentUser,
      );
    } on WebSocketException {
      rethrow;
    } catch (e) {
      throw WebSocketException('Authentication failed: $e');
    }
  }
}

class WebSocketException implements Exception {
  final String message;

  WebSocketException(this.message);

  @override
  String toString() => 'WebSocketException: $message';
}
