import 'package:vania_redis/vania_redis.dart';
import 'package:test/test.dart';

void main() {
  test('builds redis config from a map', () {
    final config = RedisConfig.fromMap({
      'host': 'localhost',
      'port': '6380',
      'database': '2',
      'prefix': 'app:',
      'secure': true,
      'pool_size': '4',
    });

    expect(config.host, 'localhost');
    expect(config.port, 6380);
    expect(config.database, 2);
    expect(config.prefix, 'app:');
    expect(config.secure, isTrue);
    expect(config.poolSize, 4);
  });

  test('represents scan results', () {
    final result = RedisScanResult(cursor: 0, keys: ['a', 'b']);

    expect(result.isComplete, isTrue);
    expect(result.keys, ['a', 'b']);
  });

  test('creates reusable lua script helpers', () {
    final script = RedisScript('return KEYS[1]');

    expect(script.source, 'return KEYS[1]');
    expect(script.sha, isNull);
  });

  test('exports vania redis integration types', () {
    expect(RedisServiceProvider(), isA<RedisServiceProvider>());
    expect(RedisCacheDriver(prefix: 'test:'), isA<RedisCacheDriver>());
  });

  test('exposes new script and pubsub configuration', () {
    final config = RedisConfig.fromMap({
      'host': 'localhost',
      'scripts_path': '/tmp/scripts',
      'warm_up': true,
    });

    expect(config.scriptsPath, '/tmp/scripts');
    expect(config.warmUp, isTrue);
  });
}
