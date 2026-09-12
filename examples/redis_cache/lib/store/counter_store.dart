/// A tiny counter contract the app depends on. Two implementations back it:
/// [RedisCounterStore] for production, and an in-memory fake for tests.
abstract interface class CounterStore {
  Future<int> increment(String key);
  Future<int> current(String key);
  Future<void> reset(String key);
}
