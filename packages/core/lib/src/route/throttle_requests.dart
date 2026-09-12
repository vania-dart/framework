class ThrottleRequests {
  final int maxAttempts;
  final Duration duration;
  final Map<String, _ThrottleData> _requests = {};

  /// Expired entries are swept periodically rather than on every request,
  /// so tracking many clients doesn't cost a full scan per call. A sweep
  /// runs when
  /// either at least `_cleanupEveryNRequests` new requests have occurred since
  /// the last sweep or the map has grown beyond `_cleanupWhenLargerThan`.
  static const int _cleanupEveryNRequests = 128;
  static const int _cleanupWhenLargerThan = 4096;
  int _sinceLastCleanup = 0;

  ThrottleRequests({required this.maxAttempts, required this.duration});

  bool request(String identifier) {
    _maybeCleanup();

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
    _maybeCleanup();
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

  void _maybeCleanup() {
    _sinceLastCleanup++;
    if (_sinceLastCleanup < _cleanupEveryNRequests &&
        _requests.length < _cleanupWhenLargerThan) {
      return;
    }
    _sinceLastCleanup = 0;
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
