---
sidebar_position: 11
---

# Caching

Vania provides a driver-based caching system. The framework ships with a file cache driver, and the `vania_redis` package adds a Redis driver.

## Configuration

Set the cache driver in `.env`:

```env
CACHE_DRIVER=file
```

The file cache stores serialized data in `storage/framework/cache/`.

## Basic Usage

```dart
import 'package:vania/vania.dart';

// Store a value with a time-to-live. `duration` is a Duration (defaults to 1 hour).
await Cache.put('user:42', 'Alice', duration: Duration(hours: 1));

// Store permanently
await Cache.forever('theme', 'dark');

// Retrieve a value
var user = await Cache.get('user:42');

// Check existence
bool exists = await Cache.has('user:42');

// Remove a value
await Cache.delete('user:42');
```

## Using Redis as Cache Driver

Install `vania_redis`:

```yaml
dependencies:
  vania_redis: ^1.0.0
```

Register the provider and set the driver:

```dart
// config/app.dart
'providers': [
  RouteServiceProvider(),
  RedisServiceProvider(),
],
```

```env
CACHE_DRIVER=redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
```

The `RedisServiceProvider` automatically registers a `redis` cache driver with the `Cache` facade.

## Registering a Custom Driver

Implement the `CacheDriver` interface:

```dart
import 'package:vania/vania.dart';

class MemcachedCacheDriver implements CacheDriver {
  @override
  Future<dynamic> get(String key) async { ... }

  @override
  Future<void> put(String key, dynamic value, {Duration duration}) async { ... }

  @override
  Future<void> forever(String key, dynamic value) async { ... }

  @override
  Future<dynamic> get(String key, [dynamic defaultValue]) async { ... }

  @override
  Future<bool> has(String key) async { ... }

  @override
  Future<void> delete(String key) async { ... }
}
```

Register it in a service provider. `registerDriver` takes a **factory function**, not an instance:

```dart
Cache.registerDriver('memcached', () => MemcachedCacheDriver());
```

Then set `CACHE_DRIVER=memcached` in your `.env`.
