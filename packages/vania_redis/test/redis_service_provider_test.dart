import 'dart:io';

import 'package:test/test.dart';
import 'package:vania_redis/vania_redis.dart';

void main() {
  group('RedisServiceProvider', () {
    test('register() installs the redis cache driver', () async {
      final provider = RedisServiceProvider(
        config: const RedisConfig(host: '127.0.0.1', port: 6379),
      );

      // Doesn't throw and returns cleanly.
      await provider.register();
    });

    test('boot() with no scriptsPath is a no-op', () async {
      final provider = RedisServiceProvider(
        config: const RedisConfig(host: '127.0.0.1', port: 6379),
      );

      // Doesn't touch the network, doesn't throw.
      await provider.boot();
      expect(Redis().scripts.scripts, isEmpty);
    });

    test('boot() loads scripts from disk into the repository', () async {
      final tmp = await Directory.systemTemp.createTemp('redis_boot_');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
        Redis().scripts.clear();
      });
      await File(
        '${tmp.path}/rate_limit.lua',
      ).writeAsString('return redis.call("INCR", KEYS[1])');

      final provider = RedisServiceProvider(
        config: RedisConfig(
          host: '127.0.0.1',
          port: 6379,
          scriptsPath: tmp.path,
        ),
      );

      await provider.register();
      await provider.boot();

      expect(Redis().scripts.get('rate_limit').source, contains('INCR'));
    });
  });
}
