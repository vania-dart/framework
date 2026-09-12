# Vania Redis

**Redis for Vania: caching, key-value commands, Pub/Sub, connection pooling, and Lua scripts.**

`vania_redis` brings Redis into a Vania app. Use it as a fast cache, as a plain key-value store, as a message bus with Pub/Sub, or to run atomic operations that a database would make awkward. Connections are pooled, and the client is lazy by default — adding the package doesn't open a connection until your app actually uses Redis.

## Install

```yaml
dependencies:
  vania_redis: ^1.0.0
```

Register the provider:

```dart
final providers = <ServiceProvider>[
  RedisServiceProvider(),
];
```

## Configure

```env
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_DB=0
REDIS_PREFIX=app:
REDIS_POOL_SIZE=2
REDIS_WARM_UP=false
```

Leave `REDIS_WARM_UP=false` and the first command opens the connection; set it to `true` to connect and preload scripts at boot.

## Commands

```dart
import 'package:vania_redis/vania_redis.dart';

await Redis().command.set('greeting', 'hello');
final greeting = await Redis().command.get('greeting');

// Atomic counter — perfect for rate limits, view counts, and the like
final views = await Redis().command.incr('page:home:views');

// Hashes, lists, sets, expirations — the usual Redis surface
await Redis().command.hSet('user:1', 'name', 'Alice');
await Redis().command.setEx('session:abc', 'data', Duration(minutes: 30));
```

## Use it as the cache driver

Point the framework's `Cache` at Redis and every `Cache.put` / `Cache.get` goes through it:

```env
CACHE_DRIVER=redis
```

```dart
await Cache.put('user:42', 'Alice', duration: Duration(hours: 1));
final name = await Cache.get('user:42');
```

## What else it does

- **Pub/Sub** — publish and subscribe to channels for lightweight messaging between processes.
- **Lua scripting** — register and run scripts for multi-step atomic operations.
- **Connection pooling** — a configurable pool, managed for you.
- **Key prefixing** — namespace everything under `REDIS_PREFIX` so multiple apps can share one Redis safely.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
