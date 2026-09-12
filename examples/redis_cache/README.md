# Redis Cache Example

A page-view counter backed by Redis, using
[`vania_redis`](../../packages/vania_redis) with the
[Vania](../../packages/core) framework.

## Design

The app depends on a small [`CounterStore`](lib/store/counter_store.dart)
contract, with two implementations:

- [`RedisCounterStore`](lib/store/redis_counter_store.dart) — real, using
  `Redis().command` (`INCR` / `GET` / `DEL`).
- an in-memory fake in the tests.

A thin [`PageViews`](lib/views/page_views.dart) service sits on top, so the
counting logic is Redis-free and unit-testable. The
[controller](lib/features/views/views_controller.dart) injects the Redis
store; [config/app.dart](lib/config/app.dart) registers `RedisServiceProvider`.

## Endpoints

| Method | Path                | Description                    |
|--------|---------------------|--------------------------------|
| POST   | `/api/views/{page}` | Record a view, return the count |
| GET    | `/api/views/{page}` | Read the current count          |

## Running

Needs a reachable Redis (`REDIS_HOST` / `REDIS_PORT`, defaults
`localhost:6379`):

```bash
docker run -p 6379:6379 redis:7

dart pub get
dart run bin/server.dart
```

```bash
curl -X POST localhost:8000/api/views/home   # {"page":"home","views":1}
curl -X POST localhost:8000/api/views/home   # {"page":"home","views":2}
curl localhost:8000/api/views/home           # {"page":"home","views":2}
```

## Tests

`PageViews` is tested against the in-memory `CounterStore`, so no Redis is
needed:

```bash
dart test
```
