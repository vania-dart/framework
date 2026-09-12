---
sidebar_position: 5
---

# Redis (vania_redis)

The `vania_redis` package provides a Redis client with connection pooling, cache driver integration, pub/sub messaging, and Lua script support.

## Installation

```yaml
dependencies:
  vania_redis: ^1.0.0
```

## Configuration

Add Redis settings to `.env`:

```env
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DATABASE=0
REDIS_PREFIX=myapp:
```

Register the service provider in `config/app.dart`:

```dart
'providers': [
  RouteServiceProvider(),
  RedisServiceProvider(),
],
```

Or configure programmatically:

```dart
var config = RedisConfig(
  host: 'localhost',
  port: 6379,
  password: 'secret',
  database: 0,
  prefix: 'myapp:',
  poolSize: 5,
  warmUp: true,
);

await Redis().connect(config);
```

## Basic Commands

```dart
import 'package:vania_redis/vania_redis.dart';

// String operations
await Redis().command.set('user:1:name', 'Alice');
String? name = await Redis().command.get('user:1:name');

// With expiration
await Redis().command.setEx('session:abc', 'data', Duration(minutes: 30));

// Set if not exists
bool wasSet = await Redis().command.setNx('lock:job', 'worker_1');

// Delete
await Redis().command.del(['user:1:name']);

// Check existence
bool exists = await Redis().command.exists('user:1:name');
```

## Hash Operations

```dart
// Set fields
await Redis().command.hSet('user:1', 'name', 'Alice');
await Redis().command.hSet('user:1', 'email', 'alice@example.com');

// Get a field
String? name = await Redis().command.hGet('user:1', 'name');

// Get all fields
Map<String, String> user = await Redis().command.hGetAll('user:1');

// Delete a field
await Redis().command.hDel('user:1', ['email']);
```

## List Operations

```dart
// Push to list
await Redis().command.lPush('queue:emails', ['job_1', 'job_2']);
await Redis().command.rPush('queue:emails', ['job_3']);

// Pop from list
String? job = await Redis().command.lPop('queue:emails');

// Get range
List<String> items = await Redis().command.lRange('queue:emails', 0, -1);
```

## Set Operations

```dart
await Redis().command.sAdd('tags:post:1', ['dart', 'backend', 'api']);
Set<String> tags = await Redis().command.sMembers('tags:post:1');
bool isMember = await Redis().command.sIsMember('tags:post:1', 'dart');
```

## Sorted Set Operations

```dart
await Redis().command.zAdd('leaderboard', {'alice': 100, 'bob': 85, 'charlie': 92});
List<String> top = await Redis().command.zRange('leaderboard', 0, 2);
```

## Using as a Cache Driver

The `RedisServiceProvider` automatically registers Redis as a cache driver. Set it in `.env`:

```env
CACHE_DRIVER=redis
```

Then use the `Cache` facade as normal:

```dart
await Cache.put('key', 'value', duration: 3600);
var value = await Cache.get('key');
await Cache.delete('key');
```

## Pub/Sub

```dart
// Subscriber
var pubsub = await Redis().pubsub(channels: ['notifications']);
pubsub.stream.listen((message) {
  print('Channel: ${message.channel}, Data: ${message.data}');
});

// Publisher (from another connection or service)
await Redis().command.publish('notifications', 'New order received');

// Pattern subscribe
var pubsub = await Redis().pubsub(patterns: ['user:*']);
```

## Connection Pool

```dart
// Execute with a pooled connection
var result = await Redis().pool.execute((commands) async {
  await commands.set('key', 'value');
  return await commands.get('key');
});
```

## Lua Scripting

```dart
// Register a script
Redis().scripts.register('increment_if_exists', '''
  local current = redis.call('GET', KEYS[1])
  if current then
    return redis.call('INCRBY', KEYS[1], ARGV[1])
  end
  return nil
''');

// Run it
var result = await Redis().scripts.run(
  Redis().command,
  'increment_if_exists',
  keys: ['counter'],
  arguments: ['5'],
);

// Load scripts from a directory
await Redis().scripts.loadDirectory('lib/redis_scripts');
```

## Transactions

```dart
await Redis().command.transaction((pipe) async {
  pipe.set('key1', 'value1');
  pipe.set('key2', 'value2');
  pipe.incr('counter');
});
```

## Pipelining

```dart
await Redis().command.pipeline((pipe) {
  pipe.set('a', '1');
  pipe.set('b', '2');
  pipe.set('c', '3');
});
```

## Cleanup

```dart
await Redis().close();
```
