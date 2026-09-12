---
sidebar_position: 5
---

# Walkthrough: Redis Cache

**Sample:** `examples/redis_cache` · **Needs:** Redis

A page-view counter backed by Redis. Every time a page is viewed, a counter goes up; you can also read the current count. The app is tiny, but it demonstrates a habit worth copying: the counting logic never mentions Redis, because Redis sits behind a small interface.

See the [Redis](../../packages/redis.md) package page for the full command surface.

## Run it

Start Redis, then the app:

```bash
docker run -p 6379:6379 redis:7

cd examples/redis_cache
dart pub get
dart run bin/server.dart
```

```bash
curl -X POST localhost:8000/api/views/home   # {"page":"home","views":1}
curl -X POST localhost:8000/api/views/home   # {"page":"home","views":2}
curl localhost:8000/api/views/home           # {"page":"home","views":2}
```

## Registering Redis

The `RedisServiceProvider` is added in `config/app.dart` with its connection settings:

```dart
// lib/config/app.dart
'providers': <ServiceProvider>[
  RedisServiceProvider(
    config: RedisConfig(
      host: env('REDIS_HOST', 'localhost'),
      port: env<int>('REDIS_PORT', 6379),
    ),
  ),
  RouteServiceProvider(),
],
```

Once registered, `Redis().command` is available anywhere as a connection-pooled client.

## The interface that keeps Redis out of the logic

The app depends on a three-method contract, not on Redis:

```dart
// lib/store/counter_store.dart
abstract interface class CounterStore {
  Future<int> increment(String key);
  Future<int> current(String key);
  Future<void> reset(String key);
}
```

The real implementation maps those three methods onto Redis commands — `INCR`, `GET`, `DEL`:

```dart
// lib/store/redis_counter_store.dart
class RedisCounterStore implements CounterStore {
  String _key(String key) => 'views:$key';

  @override
  Future<int> increment(String key) async =>
      await Redis().command.incr(_key(key)) ?? 0;

  @override
  Future<int> current(String key) async {
    final value = await Redis().command.get(_key(key));
    return int.tryParse(value ?? '0') ?? 0;
  }

  @override
  Future<void> reset(String key) async {
    await Redis().command.del(_key(key));
  }
}
```

`INCR` is the right tool here specifically because it is atomic: two simultaneous requests both increment correctly without a read-modify-write race. That is a Redis strength worth reaching for, not just a cache.

Note the `views:` prefix — namespacing your keys keeps this app's data from colliding with anything else sharing the Redis instance.

## The service on top

`PageViews` is the application logic. It talks to a `CounterStore` and has no idea Redis exists:

```dart
// lib/views/page_views.dart
class PageViews {
  PageViews(this._store);
  final CounterStore _store;

  Future<int> record(String page) => _store.increment(page);
  Future<int> count(String page)  => _store.current(page);
  Future<void> reset(String page) => _store.reset(page);
}
```

The controller wires the real store into the service — the one place the choice of Redis is made:

```dart
// lib/features/views/views_controller.dart
final PageViews _pageViews = PageViews(RedisCounterStore());

class ViewsController extends Controller {
  Future<Response> record(Request req, String page) async =>
      Response.json({'page': page, 'views': await _pageViews.record(page)});

  Future<Response> show(Request req, String page) async =>
      Response.json({'page': page, 'views': await _pageViews.count(page)});
}
```

## The routes

```dart
// lib/features/views/views_route.dart
Router.post('/views/{page}', viewsController.record);
Router.get('/views/{page}', viewsController.show);
```

## Testing without Redis

Because `PageViews` depends on the `CounterStore` interface, the tests hand it an in-memory fake and never start Redis:

```bash
dart test
```

The counting logic is verified in full; the Redis wiring is a thin, boring adapter that does not need a test to prove `INCR` increments.

## What to take away

- Put your infrastructure (Redis, here) behind a **small interface**, and keep your logic on the interface side of it.
- Redis is more than a cache — atomic operations like `INCR` solve concurrency problems cleanly.
- **Namespace your keys** (`views:home`) so multiple apps can share one Redis safely.
- The interface seam is what lets the logic be tested without the service running — the same pattern as [Todos](todos.md) and [Basic Authentication](basic-authentication.md).
