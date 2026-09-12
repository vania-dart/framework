import 'package:vania/vania.dart';
import 'package:vania/service_provider.dart';
import 'package:vania_redis/vania_redis.dart';
import 'package:redis_cache/app/providers/route_service_provider.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'redis_cache'),
  'url': env('APP_URL', 'http://localhost'),
  'providers': <ServiceProvider>[
    RedisServiceProvider(
      config: RedisConfig(
        host: env('REDIS_HOST', 'localhost'),
        port: env<int>('REDIS_PORT', 6379),
      ),
    ),
    RouteServiceProvider(),
  ],
};
