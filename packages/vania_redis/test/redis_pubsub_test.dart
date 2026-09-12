import 'package:test/test.dart';
import 'package:vania_redis/vania_redis.dart';

void main() {
  group('RedisMessage', () {
    test('holds message metadata for the SUBSCRIBE codec', () {
      const message = RedisMessage<String>(
        kind: 'message',
        channel: 'news',
        payload: 'breaking',
      );

      expect(message.channel, 'news');
      expect(message.kind, 'message');
      expect(message.payload, 'breaking');
      expect(message.pattern, isNull);
    });

    test('holds pattern metadata for the PSUBSCRIBE codec', () {
      const message = RedisMessage<String>(
        kind: 'pmessage',
        channel: 'news.tech',
        pattern: 'news.*',
        payload: 'ai',
      );

      expect(message.pattern, 'news.*');
      expect(message.kind, 'pmessage');
    });
  });
}
