class ThrottleRequests {
  final int maxAttempts;
  final Duration duration;
  final Map<String, _ThrottleData> _requests = {};

  ThrottleRequests({required this.maxAttempts, required this.duration});

  bool request(String identifier) {
    _cleanup();

    final now = DateTime.now();
    final data =
        _requests[identifier] ?? _ThrottleData(attempts: 0, firstAttempt: now);

    if (data.attempts >= maxAttempts &&
        now.difference(data.firstAttempt) < duration) {
      return false;
    }

    if (now.difference(data.firstAttempt) >= duration) {
      data.attempts = 1;
      data.firstAttempt = now;
    } else {
      data.attempts++;
    }

    _requests[identifier] = data;
    return true;
  }

  int remainingAttempts(String identifier) {
    _cleanup();
    final data = _requests[identifier];
    if (data == null) return maxAttempts;

    if (DateTime.now().difference(data.firstAttempt) >= duration) {
      return maxAttempts;
    }

    return maxAttempts - data.attempts;
  }

  Duration retryAfter(String identifier) {
    final data = _requests[identifier];
    if (data == null) return Duration.zero;

    final elapsed = DateTime.now().difference(data.firstAttempt);
    if (elapsed >= duration) return Duration.zero;

    return duration - elapsed;
  }

  DateTime resetTime() {
    return DateTime.now().add(duration);
  }

  void _cleanup() {
    final now = DateTime.now();
    _requests.removeWhere(
      (_, data) => now.difference(data.firstAttempt) >= duration,
    );
  }
}

class _ThrottleData {
  DateTime firstAttempt;
  int attempts;

  _ThrottleData({required this.firstAttempt, required this.attempts});
}
