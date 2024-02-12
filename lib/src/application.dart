import 'dart:io';

import 'package:vania/src/container.dart';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/server/base_http_server.dart';
import 'package:vania/vania.dart';

class Application extends Container {
  static Application? _singleton;

  factory Application() {
    _singleton ??= Application._internal();
    return _singleton!;
  }

  Application._internal();

  BaseHttpServer get server => BaseHttpServer();

  Future<void> initialize({required Map<String, dynamic> config}) async {
    try {
      if (config['key'] == '' || config['key'] == null) {
        throw Exception('Key not found');
      }

      Config().setApplicationConfig = config;

      List<ServiceProvider> provider = config['providers'];

      for (ServiceProvider provider in provider) {
        provider.register();
        provider.boot();
      }

      DatabaseConfig? db = Config().get('database');
      if (db != null) {
        await db.driver?.init(Config().get('database'));
      }

      server.startServer(host: config['host'], port: config['port']);
    } on InvalidArgumentException catch (_) {
      print('Error establishing a database connection');
    }
  }

  Future<void> close() async {
    server.httpServer?.close();
  }
}
