/// A tiny in-memory counter. Kept separate from the HTTP layer so the
/// behaviour can be tested without spinning up a server.
class Counter {
  int _value = 0;

  int get value => _value;

  int increment([int by = 1]) => _value += by;

  int decrement([int by = 1]) => _value -= by;

  int reset() => _value = 0;
}

/// Single shared counter used by the controller.
final Counter counter = Counter();
