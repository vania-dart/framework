import 'dart:async';

import 'package:vania/vania.dart';

class Redis {
  late Commands<String, String> command;

  static final Completer<void> _completer = Completer<void>();

  Future<void> get initialized => _completer.future;

  Redis._internal();
  static Redis? _singleton;
  factory Redis() {
    if (_singleton == null) {
      _singleton = Redis._internal();
      _singleton!._initRedis().then((_) {
        _completer.complete();
      });
    }
    return _singleton!;
  }

  Future<void> _initRedis() async {
    RedisClient cli = await RedisClient.connect(
      env<String>('REDIS_HOST', '127.0.0.1'),
      env<int>('REDIS_PORT', 6379),
      db: env<int>('REDIS_DB', 0),
      username: env('REDIS_USERNAME'),
      password: env<String>('REDIS_PASSWORD'),
    );
    command = cli.getCommands<String, String>();
  }
}
