import 'dart:collection';

class WebSocketRateLimiter {
  WebSocketRateLimiter({
    required this.maxRequests,
    required this.window,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int maxRequests;
  final Duration window;
  final DateTime Function() _clock;

  final Map<String, Queue<DateTime>> _requests = {};
  final Map<String, int> _violations = {};

  /// Check if a request is allowed for the given key
  bool isAllowed(String key) {
    final now = _clock();
    final windowStart = now.subtract(window);

    // Get or create request queue
    _requests.putIfAbsent(key, () => Queue<DateTime>());

    // Remove old requests outside the window
    while (_requests[key]!.isNotEmpty &&
        _requests[key]!.first.isBefore(windowStart)) {
      _requests[key]!.removeFirst();
    }

    // Check if under limit
    if (_requests[key]!.length >= maxRequests) {
      _violations[key] = (_violations[key] ?? 0) + 1;
      return false;
    }

    // Add new request
    _requests[key]!.add(now);
    return true;
  }

  /// Get remaining requests for a key
  int remaining(String key) {
    final now = _clock();
    final windowStart = now.subtract(window);

    if (!_requests.containsKey(key)) {
      return maxRequests;
    }

    // Count requests in current window
    int count = 0;
    for (final requestTime in _requests[key]!) {
      if (requestTime.isAfter(windowStart)) {
        count++;
      }
    }

    final remainingRequests = maxRequests - count;
    return remainingRequests < 0 ? 0 : remainingRequests;
  }

  /// Get reset time for a key
  DateTime? getResetTime(String key) {
    if (!_requests.containsKey(key) || _requests[key]!.isEmpty) {
      return null;
    }
    return _requests[key]!.first.add(window);
  }

  /// Get violation count for a key
  int getViolations(String key) {
    return _violations[key] ?? 0;
  }

  /// Reset a specific key
  void reset(String key) {
    _requests.remove(key);
    _violations.remove(key);
  }

  /// Reset all keys
  void resetAll() {
    _requests.clear();
    _violations.clear();
  }

  /// Clean up old entries
  void cleanup() {
    final now = _clock();
    final keysToRemove = <String>[];

    for (final entry in _requests.entries) {
      if (entry.value.isEmpty) {
        keysToRemove.add(entry.key);
      } else {
        final lastRequest = entry.value.last;
        if (now.difference(lastRequest) > window) {
          keysToRemove.add(entry.key);
        }
      }
    }

    for (final key in keysToRemove) {
      _requests.remove(key);
      _violations.remove(key);
    }
  }

  /// Get rate limit info for a key
  RateLimitInfo getInfo(String key) {
    final remainingCount = remaining(key);
    final resetTime = getResetTime(key);
    final violationCount = getViolations(key);

    return RateLimitInfo(
      limit: maxRequests,
      remaining: remainingCount,
      reset: resetTime,
      violations: violationCount,
    );
  }
}

class RateLimitInfo {
  final int limit;
  final int remaining;
  final DateTime? reset;
  final int violations;

  RateLimitInfo({
    required this.limit,
    required this.remaining,
    this.reset,
    required this.violations,
  });

  Map<String, dynamic> toJson() {
    return {
      'limit': limit,
      'remaining': remaining,
      'reset': reset?.toIso8601String(),
      'violations': violations,
    };
  }
}
