import 'dart:async';

import 'package:redis/redis.dart' as redis;

import '../config.dart';
import '../exception.dart';
import '../pubsub/redis_pubsub.dart';
import 'codec.dart';
import 'commands.dart';

class MultiCodec {
  final List<RedisCodec> codecs = [
    RedisCodec(encoder: StringEncoder(), decoder: StringDecoder()),
    RedisCodec(encoder: IntEncoder(), decoder: IntDecoder()),
    RedisCodec(encoder: DoubleEncoder(), decoder: DoubleDecoder()),
  ];

  String encode<T>(T value) {
    if (value == null) return '';
    for (final codec in codecs) {
      if (codec.encoder.isSupporting<T>(value)) {
        return codec.encoder.convert(value);
      }
    }
    return value.toString();
  }

  T decode<T>(dynamic value) {
    if (value is! String) return value as T;
    for (final codec in codecs) {
      if (codec.decoder.isSupporting<T>(value)) {
        return codec.decoder.convert(value);
      }
    }
    throw RedisConvertException('no decoder found for $T');
  }

  void registerCodec(RedisCodec codec) {
    codecs.add(codec);
  }
}

class CommandsClient<K, V> implements Commands<K, V> {
  CommandsClient(this._command);

  final redis.Command _command;
  final MultiCodec keyCodec = MultiCodec();
  final MultiCodec valueCodec = MultiCodec();

  @override
  Future<int?> append(K key, V value) {
    return _integer(['APPEND', _key(key), _value(value)]);
  }

  @override
  Future<int?> bitCount(K key, {int? start, int? end}) {
    final command = <dynamic>['BITCOUNT', _key(key)];
    if (start != null && end != null) {
      command.addAll([start, end]);
    }
    return _integer(command);
  }

  @override
  Future<int?> bitOp(String operation, K destKey, List<K> keys) {
    return _integer(['BITOP', operation, _key(destKey), ...keys.map(_key)]);
  }

  @override
  Future<int?> bitPos(K key, int bit, {int? start, int? end}) {
    final command = ['BITPOS', _key(key), bit];
    if (start != null && end != null) {
      command.addAll([start, end]);
    }
    return _integer(command);
  }

  @override
  Future<int?> decr(K key) => _integer(['DECR', _key(key)]);

  @override
  Future<int?> decrBy(K key, int decrement) {
    return _integer(['DECRBY', _key(key), decrement]);
  }

  @override
  Future<bool> del(K key) async => await _integer(['DEL', _key(key)]) == 1;

  @override
  Future<int> delMany(List<K> keys) async {
    if (keys.isEmpty) return 0;
    return await _integer(['DEL', ...keys.map(_key)]) ?? 0;
  }

  @override
  Future<void> discard() async {
    await raw(['DISCARD']);
  }

  @override
  Future<dynamic> eval(
    String script, {
    List<String> keys = const [],
    List<dynamic> arguments = const [],
  }) {
    return raw(['EVAL', script, keys.length, ...keys, ...arguments]);
  }

  @override
  Future<dynamic> evalSha(
    String sha, {
    List<String> keys = const [],
    List<dynamic> arguments = const [],
  }) {
    return raw(['EVALSHA', sha, keys.length, ...keys, ...arguments]);
  }

  @override
  Future<void> exec() async {
    await raw(['EXEC']);
  }

  @override
  Future<bool> exists(K key) async {
    return await _integer(['EXISTS', _key(key)]) == 1;
  }

  @override
  Future<int> existsMany(List<K> keys) async {
    if (keys.isEmpty) return 0;
    return await _integer(['EXISTS', ...keys.map(_key)]) ?? 0;
  }

  @override
  Future<bool> expire(K key, Duration duration) async {
    return await _integer(['EXPIRE', _key(key), duration.inSeconds]) == 1;
  }

  @override
  Future<V?> get(K key) async => _decodeNullable(await raw(['GET', _key(key)]));

  @override
  Future<int?> getBit(K key, int offset) =>
      _integer(['GETBIT', _key(key), offset]);

  @override
  Future<String?> getOption(String option) async {
    final response = await raw(['CONFIG', 'GET', option]);
    if (response is List && response.length > 1) return response[1]?.toString();
    return null;
  }

  @override
  Future<V?> getRange(K key, int start, int end) {
    return raw(['GETRANGE', _key(key), start, end]).then(_decodeNullable);
  }

  @override
  Future<V?> getSet(K key, V value) {
    return raw(['GETSET', _key(key), _value(value)]).then(_decodeNullable);
  }

  @override
  Future<V?> getdel(K key) => raw(['GETDEL', _key(key)]).then(_decodeNullable);

  @override
  Future<List<String>> keys(String pattern) async {
    final response = await raw(['KEYS', pattern]);
    if (response is! List) return [];
    return response.map((key) => key.toString()).toList();
  }

  @override
  Future<int?> hDel(K key, List<String> fields) {
    return _integer(['HDEL', _key(key), ...fields]);
  }

  @override
  Future<bool> hExists(K key, String field) async {
    return await _integer(['HEXISTS', _key(key), field]) == 1;
  }

  @override
  Future<V?> hGet(K key, String field) {
    return raw(['HGET', _key(key), field]).then(_decodeNullable);
  }

  @override
  Future<Map<String, V>> hGetAll(K key) async {
    final response = await raw(['HGETALL', _key(key)]);
    if (response is! List) return {};
    final result = <String, V>{};
    for (var i = 0; i + 1 < response.length; i += 2) {
      result[response[i].toString()] = valueCodec.decode<V>(response[i + 1]);
    }
    return result;
  }

  @override
  Future<List<String>> hKeys(K key) async {
    final response = await raw(['HKEYS', _key(key)]);
    if (response is! List) return [];
    return response.map((field) => field.toString()).toList();
  }

  @override
  Future<int?> hLen(K key) => _integer(['HLEN', _key(key)]);

  @override
  Future<int?> hSet(K key, String field, V value) {
    return _integer(['HSET', _key(key), field, _value(value)]);
  }

  @override
  Future<List<V>> hVals(K key) async {
    final response = await raw(['HVALS', _key(key)]);
    if (response is! List) return [];
    return response.map((value) => valueCodec.decode<V>(value)).toList();
  }

  @override
  Future<int?> incr(K key) => _integer(['INCR', _key(key)]);

  @override
  Future<int?> incrBy(K key, int increment) {
    return _integer(['INCRBY', _key(key), increment]);
  }

  @override
  Future<double?> incrByFloat(K key, double increment) async {
    final response = await raw(['INCRBYFLOAT', _key(key), increment]);
    return double.tryParse(response.toString());
  }

  @override
  Future<V?> lpop(K key) => raw(['LPOP', _key(key)]).then(_decodeNullable);

  @override
  Future<int?> llen(K key) => _integer(['LLEN', _key(key)]);

  @override
  Future<bool> lset(K key, int index, V value) async {
    return await raw(['LSET', _key(key), index, _value(value)]) == 'OK';
  }

  @override
  Future<int?> lpush(K key, List<V> values) {
    return _integer(['LPUSH', _key(key), ...values.map(_value)]);
  }

  @override
  Future<List<V>> lrange(K key, int startIndex, int endIndex) async {
    final response = await raw(['LRANGE', _key(key), startIndex, endIndex]);
    if (response is! List) return [];
    return response.map((value) => valueCodec.decode<V>(value)).toList();
  }

  @override
  Future<List<V?>> mGet(List<K> keys) async {
    if (keys.isEmpty) return [];
    final response = await raw(['MGET', ...keys.map(_key)]);
    if (response is! List) return [];
    return response.map(_decodeNullable).toList();
  }

  @override
  Future<bool> mSet(Map<K, V> keyValues) async {
    if (keyValues.isEmpty) return true;
    final command = ['MSET'];
    keyValues.forEach((key, value) {
      command.addAll([_key(key), _value(value)]);
    });
    return await raw(command) == 'OK';
  }

  @override
  Future<bool> mSetNX(Map<K, V> keyValues) async {
    if (keyValues.isEmpty) return true;
    final command = ['MSETNX'];
    keyValues.forEach((key, value) {
      command.addAll([_key(key), _value(value)]);
    });
    return await _integer(command) == 1;
  }

  @override
  Future<void> multi() async {
    await raw(['MULTI']);
  }

  @override
  Future<bool> pSetEx(K key, int ttl, V value) async {
    return await raw(['PSETEX', _key(key), ttl, _value(value)]) == 'OK';
  }

  @override
  Future<bool> persist(K key) async {
    return await _integer(['PERSIST', _key(key)]) == 1;
  }

  @override
  Future<List<dynamic>> pipeline(List<List<dynamic>> commands) async {
    if (commands.isEmpty) return [];
    _command.pipe_start();
    final futures = [for (final command in commands) raw(command)];
    _command.pipe_end();
    return Future.wait(futures);
  }

  @override
  Future<int?> pttl(K key) => _integer(['PTTL', _key(key)]);

  @override
  Future<int?> publish(String channel, V message) {
    return _integer(['PUBLISH', channel, _value(message)]);
  }

  @override
  Future<dynamic> raw(List<dynamic> command) {
    return _command.send_object(command);
  }

  @override
  Future<V?> rpop(K key) => raw(['RPOP', _key(key)]).then(_decodeNullable);

  @override
  Future<int?> rpush(K key, List<V> values) {
    return _integer(['RPUSH', _key(key), ...values.map(_value)]);
  }

  @override
  Future<int?> sAdd(K key, List<V> members) {
    return _integer(['SADD', _key(key), ...members.map(_value)]);
  }

  @override
  Future<RedisScanResult> scan({
    int cursor = 0,
    String? match,
    int? count,
    String? type,
  }) async {
    final command = ['SCAN', cursor];
    if (match != null) command.addAll(['MATCH', match]);
    if (count != null) command.addAll(['COUNT', count]);
    if (type != null) command.addAll(['TYPE', type]);
    final response = await raw(command);
    if (response is! List || response.length < 2) {
      return const RedisScanResult(cursor: 0, keys: []);
    }
    final keys = response[1] is List
        ? (response[1] as List).map((key) => key.toString()).toList()
        : <String>[];
    return RedisScanResult(
      cursor: int.tryParse(response[0].toString()) ?? 0,
      keys: keys,
    );
  }

  @override
  Future<String?> scriptFlush() async {
    final response = await raw(['SCRIPT', 'FLUSH']);
    return response?.toString();
  }

  @override
  Future<List<bool>> scriptExists(List<String> sha1) async {
    final response = await raw(['SCRIPT', 'EXISTS', ...sha1]);
    if (response is! List) return [];
    return response.map((value) => value == 1).toList();
  }

  @override
  Future<String> scriptLoad(String script) async {
    return (await raw(['SCRIPT', 'LOAD', script])).toString();
  }

  @override
  Future<bool> set(K key, V value) async {
    return await raw(['SET', _key(key), _value(value)]) == 'OK';
  }

  @override
  Future<int?> setBit(K key, int offset, int value) {
    return _integer(['SETBIT', _key(key), offset, value]);
  }

  @override
  Future<bool> setEx(K key, int ttl, V value) async {
    return await raw(['SETEX', _key(key), ttl, _value(value)]) == 'OK';
  }

  @override
  Future<bool> setNx(K key, V value) async {
    return await _integer(['SETNX', _key(key), _value(value)]) == 1;
  }

  @override
  Future<bool> setOption(String option, String value) async {
    return await raw(['CONFIG', 'SET', option, value]) == 'OK';
  }

  @override
  Future<int?> setRange(K key, int offset, V value) {
    return _integer(['SETRANGE', _key(key), offset, _value(value)]);
  }

  @override
  Future<bool> sIsMember(K key, V member) async {
    return await _integer(['SISMEMBER', _key(key), _value(member)]) == 1;
  }

  @override
  Future<List<V>> sMembers(K key) async {
    final response = await raw(['SMEMBERS', _key(key)]);
    if (response is! List) return [];
    return response.map((value) => valueCodec.decode<V>(value)).toList();
  }

  @override
  Future<int?> sRem(K key, List<V> members) {
    return _integer(['SREM', _key(key), ...members.map(_value)]);
  }

  @override
  Future<int?> strlen(K key) => _integer(['STRLEN', _key(key)]);

  @override
  Future<List<dynamic>> transaction(
    Future<void> Function(RedisTransaction tx) action,
  ) async {
    final transaction = await _command.multi();
    final queued = <Future<dynamic>>[];
    await action(
      RedisTransaction((command) {
        final future = transaction.send_object(command);
        queued.add(future);
        return future;
      }),
    );
    await transaction.exec();
    return Future.wait(queued);
  }

  @override
  Future<int?> ttl(K key) => _integer(['TTL', _key(key)]);

  @override
  Future<int?> zAdd(K key, Map<V, num> scores) {
    final command = <dynamic>['ZADD', _key(key)];
    scores.forEach((member, score) {
      command.addAll([score, _value(member)]);
    });
    return _integer(command);
  }

  @override
  Future<List<V>> zRange(K key, int start, int stop) async {
    final response = await raw(['ZRANGE', _key(key), start, stop]);
    if (response is! List) return [];
    return response.map((value) => valueCodec.decode<V>(value)).toList();
  }

  @override
  Future<int?> zRem(K key, List<V> members) {
    return _integer(['ZREM', _key(key), ...members.map(_value)]);
  }

  @override
  Future<double?> zScore(K key, V member) async {
    final response = await raw(['ZSCORE', _key(key), _value(member)]);
    if (response == null) return null;
    return double.tryParse(response.toString());
  }

  V? _decodeNullable(dynamic value) {
    if (value == null) return null;
    return valueCodec.decode<V>(value);
  }

  Future<int?> _integer(List<dynamic> command) async {
    final response = await raw(command);
    if (response is int) return response;
    return int.tryParse(response.toString());
  }

  String _key(K key) => keyCodec.encode<K>(key);

  String _value(dynamic value) => valueCodec.encode(value);
}

class RedisClient {
  RedisClient._(this._connection, this._command, this.config);

  final redis.RedisConnection _connection;
  final redis.Command _command;
  final RedisConfig config;

  static Future<RedisClient> connect(
    String host,
    int port, {
    int db = 0,
    String? username,
    String? password,
    bool secure = false,
  }) async {
    final config = RedisConfig(
      host: host,
      port: port,
      database: db,
      username: username,
      password: password,
      secure: secure,
    );
    return connectWithConfig(config);
  }

  static Future<RedisClient> connectWithConfig(RedisConfig config) async {
    final connection = redis.RedisConnection();
    final command = config.secure
        ? await connection.connectSecure(config.host, config.port)
        : await connection.connect(config.host, config.port);

    if (config.password != null && config.password!.isNotEmpty) {
      if (config.username != null && config.username!.isNotEmpty) {
        await command.send_object(['AUTH', config.username, config.password]);
      } else {
        await command.send_object(['AUTH', config.password]);
      }
    }
    if (config.database > 0) {
      await command.send_object(['SELECT', config.database]);
    }
    return RedisClient._(connection, command, config);
  }

  Commands<K, V> getCommands<K, V>() => CommandsClient<K, V>(_command);

  Future<RedisPubSub<V>> subscribe<V>({
    List<String> channels = const [],
    List<String> patterns = const [],
  }) async {
    final client = await connectWithConfig(config);
    return RedisPubSub.own<V>(
      client._command,
      client._connection,
      channels: channels,
      patterns: patterns,
    );
  }

  Future<void> close() => _connection.close();
}
