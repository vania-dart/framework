class ThrottleRequests {
  final int maxAttempts;
  final Duration duration;
  final Map<String, _RateLimit> _limits = {};

  ThrottleRequests({required this.maxAttempts, required this.duration});

  bool request(String ip) {
    final currentTime = DateTime.now();

    _limits.putIfAbsent(ip, () => _RateLimit(0, currentTime));
    final limit = _limits[ip]!;

    if (currentTime.difference(limit.windowStart).compareTo(duration) >= 0) {
      limit.count = 0;
      limit.windowStart = currentTime;
    }

    if (limit.count < maxAttempts) {
      limit.count++;
      return true;
    } else {
      return false;
    }
  }
}

class _RateLimit {
  int count;
  DateTime windowStart;

  _RateLimit(this.count, this.windowStart);
}
