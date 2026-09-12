import 'package:test/test.dart';
import 'package:vania/src/route/throttle_requests.dart';

void main() {
  group('ThrottleRequests', () {
    test('when under limit returns true for each request', () {
      final t = ThrottleRequests(
        maxAttempts: 3,
        duration: const Duration(seconds: 10),
      );
      expect(t.request('ip-1'), isTrue);
      expect(t.request('ip-1'), isTrue);
      expect(t.request('ip-1'), isTrue);
    });

    test('when limit exceeded returns false', () {
      final t = ThrottleRequests(
        maxAttempts: 2,
        duration: const Duration(seconds: 10),
      );
      expect(t.request('ip-1'), isTrue);
      expect(t.request('ip-1'), isTrue);
      expect(t.request('ip-1'), isFalse);
    });

    test('remainingAttempts is maxAttempts for unknown identifier', () {
      final t = ThrottleRequests(
        maxAttempts: 5,
        duration: const Duration(seconds: 10),
      );
      expect(t.remainingAttempts('never-seen'), equals(5));
    });

    test('10k requests do not degrade (amortized O(1) cleanup)', () {
      final t = ThrottleRequests(
        maxAttempts: 60,
        duration: const Duration(minutes: 1),
      );
      final sw = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        t.request('ip-$i');
      }
      sw.stop();
      expect(sw.elapsed.inSeconds, lessThan(2));
    });
  });
}
