import 'package:vania_redis/vania_redis.dart';

/// Demonstrates the three core Redis patterns wired through vania_redis:
///   1. commands via the [Redis] singleton
///   2. Pub/Sub over a dedicated connection
///   3. Lua scripts loaded from disk with EVALSHA caching
///
/// Expects a Redis server on `127.0.0.1:6379`.
Future<void> main() async {
  await Redis().connect();

  // (1) Commands
  await Redis().command.set('vania:hello', 'world');
  final value = await Redis().command.get('vania:hello');
  print('vania:hello = $value');

  // (2) Pub/Sub — separate connection, own it, close when done.
  final sub = await Redis().pubsub<String>(channels: ['vania:events']);
  final subFuture = sub.stream.first;
  await Redis().command.publish('vania:events', 'sample-event');
  final message = await subFuture;
  print('received on ${message.channel}: ${message.payload}');
  await sub.close();

  // (3) Lua scripts. Preload from a directory and run by name. First call
  //     of `bump` uses EVAL, subsequent calls use EVALSHA.
  Redis().scripts.register('bump', '''
    return redis.call('INCR', KEYS[1])
  ''');
  await Redis().scripts.preloadAll(Redis().command);
  final one = await Redis().scripts.run(
    Redis().command,
    'bump',
    keys: ['vania:counter'],
  );
  final two = await Redis().scripts.run(
    Redis().command,
    'bump',
    keys: ['vania:counter'],
  );
  print('counter: $one → $two');

  await Redis().close();
}
