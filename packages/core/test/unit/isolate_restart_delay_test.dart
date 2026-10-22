import 'package:test/test.dart';
import 'package:vania/src/server/server_isolates.dart';

void main() {
  test('an isolate that keeps dying at start waits longer each time, '
      'up to a minute', () {
    var retryAfter = const Duration(seconds: 1);
    final waits = <int>[];
    for (var i = 0; i < 9; i++) {
      final (:wait, :next) = isolateRestartDelay(
        retryAfter,
        crashedEarly: true,
      );
      waits.add(wait.inSeconds);
      retryAfter = next;
    }
    expect(waits, [1, 2, 4, 8, 16, 32, 60, 60, 60]);
  });

  test('one that ran a while is replaced at once, and starts over', () {
    final (:wait, :next) = isolateRestartDelay(
      const Duration(seconds: 32),
      crashedEarly: false,
    );
    expect(wait, const Duration(seconds: 1));
    expect(next, const Duration(seconds: 1));
  });
}
