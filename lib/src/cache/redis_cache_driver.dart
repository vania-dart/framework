import 'package:vania/vania.dart';

class RedisCacheDriver extends CacheDriver {
  String prefix = env('REDIS_PREFIX', '${env('APP_NAME', 'vania')}_database_');

  @override
  Future<void> delete(String key) async {
    await Redis().initialized;
    await Redis().command.del('$prefix$key');
  }

  @override
  Future<void> forever(String key, value) async {
    await Redis().initialized;
    await Redis().command.set('$prefix$key', value);
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
    duration ??= Duration(hours: 24);
    await Redis().initialized;
    await Redis().command.setEx('$prefix$key', duration.inSeconds, value);
  }
}
