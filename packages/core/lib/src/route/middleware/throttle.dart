import 'dart:io';

import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/request/request.dart';

import 'package:vania/env.dart' show env;
import '../../exception/throttle_exception.dart';
import '../throttle_requests.dart';

/// `APP_ENV` values that count as development for
/// [Throttle.bypassInDevelopment]: the documented `local`, and
/// `development`.
const Set<String> _developmentEnvironments = {'local', 'development'};

class Throttle extends Middleware {
  final int maxAttempts;
  final Duration duration;
  final bool includeUserIdentifier;
  final String? customMessage;
  final Map<String, String>? headers;

  /// Skips the limit while `APP_ENV` is `local` or `development`.
  ///
  /// Off unless asked for: `local` is also what a `.env` copied from a
  /// development machine says, and a production app that kept it would
  /// lose its rate limits without a word.
  final bool bypassInDevelopment;

  late final ThrottleRequests _throttle;

  Throttle({
    this.maxAttempts = 60,
    this.duration = const Duration(minutes: 1),
    this.includeUserIdentifier = false,
    this.customMessage,
    this.headers,
    this.bypassInDevelopment = false,
  }) {
    _throttle = ThrottleRequests(maxAttempts: maxAttempts, duration: duration);
  }

  @override
  Future<void> handle(Request req) async {
    // Fails closed: an unset APP_ENV is treated as production, so an app
    // that never sets it still gets rate limiting.
    if (bypassInDevelopment &&
        _developmentEnvironments.contains(
          env<String>('APP_ENV', 'production'),
        )) {
      return;
    }

    final String identifier = await _getRequestIdentifier(req);
    final allowed = _throttle.request(identifier);

    // Counted after this request, so the last one allowed says 0 left.
    _addRateLimitHeaders(
      req.response,
      _throttle.remainingAttempts(identifier),
      _throttle.resetAt(identifier),
    );

    if (!allowed) {
      final retryAfter = _throttle.retryAfter(identifier);
      throw ThrottleException(
        message: customMessage ?? 'Too Many Requests. Please try again later.',
        code: HttpStatus.tooManyRequests,
        headers: {'Retry-After': retryAfter.inSeconds.toString(), ...?headers},
      );
    }
  }

  Future<String> _getRequestIdentifier(Request req) async {
    final List<String> parts = [req.clientIp ?? 'unknown'];

    if (includeUserIdentifier) {
      final userMap = req.user;
      if (userMap != null && userMap['id'] != null) {
        parts.add(userMap['id'].toString());
      }
    }

    return parts.join(':');
  }

  void _addRateLimitHeaders(
    HttpResponse response,
    int remaining,
    DateTime resetAt,
  ) {
    response.headers.add('X-RateLimit-Limit', maxAttempts.toString());
    response.headers.add('X-RateLimit-Remaining', remaining.toString());
    response.headers.add('X-RateLimit-Reset', resetAt.toIso8601String());
  }
}
