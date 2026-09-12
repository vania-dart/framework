import 'package:test/test.dart';
import 'package:counter/app/counter.dart';

void main() {
  group('Counter', () {
    late Counter counter;

    setUp(() {
      counter = Counter();
    });

    test('starts at zero', () {
      expect(counter.value, 0);
    });

    test('increment adds one by default', () {
      counter.increment();
      expect(counter.value, 1);
    });

    test('increment can add a custom amount', () {
      counter.increment(5);
      expect(counter.value, 5);
    });

    test('decrement subtracts one by default', () {
      counter.increment(3);
      counter.decrement();
      expect(counter.value, 2);
    });

    test('value can go negative', () {
      counter.decrement(2);
      expect(counter.value, -2);
    });

    test('reset returns to zero', () {
      counter.increment(10);
      counter.reset();
      expect(counter.value, 0);
    });

    test('each operation returns the new value', () {
      expect(counter.increment(), 1);
      expect(counter.increment(), 2);
      expect(counter.decrement(), 1);
      expect(counter.reset(), 0);
    });
  });
}
