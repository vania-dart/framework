import 'package:test/test.dart';
import 'package:redis_cache/store/counter_store.dart';
import 'package:redis_cache/views/page_views.dart';

/// In-memory [CounterStore] — lets the service be tested without Redis.
class InMemoryCounterStore implements CounterStore {
  final Map<String, int> _counts = {};

  @override
  Future<int> increment(String key) async =>
      _counts[key] = (_counts[key] ?? 0) + 1;

  @override
  Future<int> current(String key) async => _counts[key] ?? 0;

  @override
  Future<void> reset(String key) async => _counts.remove(key);
}

void main() {
  late PageViews views;

  setUp(() {
    views = PageViews(InMemoryCounterStore());
  });

  test('a fresh page starts at zero', () async {
    expect(await views.count('home'), 0);
  });

  test('record increments and returns the new count', () async {
    expect(await views.record('home'), 1);
    expect(await views.record('home'), 2);
    expect(await views.count('home'), 2);
  });

  test('counts are tracked per page', () async {
    await views.record('home');
    await views.record('about');
    await views.record('about');
    expect(await views.count('home'), 1);
    expect(await views.count('about'), 2);
  });

  test('reset clears a page back to zero', () async {
    await views.record('home');
    await views.reset('home');
    expect(await views.count('home'), 0);
  });
}
