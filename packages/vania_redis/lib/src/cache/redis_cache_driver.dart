import 'package:vania/foundation.dart' show CacheDriver, env;

import '../redis.dart';

class RedisCacheDriver extends CacheDriver {
  RedisCacheDriver({String? prefix})
    : prefix =
          prefix ??
          env('REDIS_PREFIX', '${env('APP_NAME', 'vania')}_database_');

  final String prefix;

  @override
  Future<void> delete(String key) async {
    await Redis().initialized;
    await Redis().command.del('$prefix$key');
  }

  @override
  Future<void> forever(String key, value) async {
    await Redis().initialized;
    await Redis().command.set('$prefix$key', value.toString());
  }

  @override
  Future get(String key, [defaultValue]) async {
    await Redis().initialized;
    return await Redis().command.get('$prefix$key') ?? defaultValue;
  }

  @override
  Future<bool> has(String key) async {
    await Redis().initialized;
    return await Redis().command.exists('$prefix$key');
  }

  @override
  Future<void> put(String key, value, {Duration? duration}) async {
    await Redis().initialized;
    await Redis().command.setEx(
      '$prefix$key',
      (duration ?? const Duration(hours: 24)).inSeconds,
      value.toString(),
    );
  }
}
