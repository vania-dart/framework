import 'dart:io';

import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/request/request.dart';

import 'package:vania/src/utils/helper.dart' show env;
import '../../exception/throttle_exception.dart';
import '../throttle_requests.dart';

class Throttle extends Middleware {
  final int maxAttempts;
  final Duration duration;
  final bool includeUserIdentifier;
  final String? customMessage;
  final Map<String, String>? headers;
  final bool bypassInDevelopment;

  late final ThrottleRequests _throttle;

  Throttle({
    this.maxAttempts = 60,
    this.duration = const Duration(minutes: 1),
    this.includeUserIdentifier = false,
    this.customMessage,
    this.headers,
    this.bypassInDevelopment = true,
  }) {
    _throttle = ThrottleRequests(maxAttempts: maxAttempts, duration: duration);
  }

  @override
  Future<void> handle(Request req) async {
    if (bypassInDevelopment &&
        env<String>('APP_ENV', 'development') == 'development') {
      return;
    }

    final String identifier = await _getRequestIdentifier(req);
    final remaining = _throttle.remainingAttempts(identifier);

    _addRateLimitHeaders(req.response, remaining);

    if (!_throttle.request(identifier)) {
      final retryAfter = _throttle.retryAfter(identifier);
      throw ThrottleException(
        message: customMessage ?? 'Too Many Requests. Please try again later.',
        code: HttpStatus.tooManyRequests,
        headers: {'Retry-After': retryAfter.inSeconds.toString(), ...?headers},
      );
    }
  }

  Future<String> _getRequestIdentifier(Request req) async {
    final List<String> parts = [req.ip ?? 'unknown'];

    if (includeUserIdentifier) {
      final userMap = req.user;
      if (userMap != null && userMap['id'] != null) {
        parts.add(userMap['id'].toString());
      }
    }

    return parts.join(':');
  }

  void _addRateLimitHeaders(HttpResponse response, int remaining) {
    response.headers.add('X-RateLimit-Limit', maxAttempts.toString());
    response.headers.add('X-RateLimit-Remaining', remaining.toString());
    response.headers.add(
      'X-RateLimit-Reset',
      _throttle.resetTime().toIso8601String(),
    );
  }
}
