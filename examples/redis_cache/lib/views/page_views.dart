import 'package:redis_cache/store/counter_store.dart';

/// Application service: counts page views through a [CounterStore]. It has
/// no Redis dependency of its own, which is what lets it be tested against
/// an in-memory store.
class PageViews {
  PageViews(this._store);

  final CounterStore _store;

  Future<int> record(String page) => _store.increment(page);

  Future<int> count(String page) => _store.current(page);

  Future<void> reset(String page) => _store.reset(page);
}
