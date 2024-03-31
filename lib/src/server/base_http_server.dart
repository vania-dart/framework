import 'dart:io';
import 'dart:isolate';

import 'package:eloquent/eloquent.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/vania.dart';

class IsolateHandler {
  final String host;
  final int port;
  final bool shared;
  const IsolateHandler({
    required this.host,
    required this.port,
    required this.shared,
  });
}

class BaseHttpServer {
  final Map<String, dynamic> config;

  BaseHttpServer({required this.config});

  final Map<int, Isolate> _isolates = <int, Isolate>{};

  HttpServer? httpServer;

  Future<void> _initConfig() async {
    Config().setApplicationConfig = config;

    List<ServiceProvider> provider = config['providers'];

    for (ServiceProvider provider in provider) {
      provider.register();
      provider.boot();
    }

    try {
      DatabaseConfig? db = Config().get('database');
      if (db != null) {
        await db.driver?.init(Config().get('database'));
      }
    } on InvalidArgumentException catch (e) {
      Logger.log(e.cause.toString(), type: Logger.ERROR);
      rethrow;
    }
  }

  void startIsolatedServer(IsolateHandler handler) async {
    await _initConfig();
    var server = await HttpServer.bind(
      handler.host,
      handler.port,
      shared: handler.shared,
    );
    server.listen(
      (HttpRequest req) {
        httpRequestHandler(req);
      },
      onError: (dynamic error) => print(error),
    );
  }

  Future<void> spawnIsolates(int count) async {
    for (int i = 0; i < count; i++) {
      Isolate isolate = await Isolate.spawn(
          startIsolatedServer,
          IsolateHandler(
            host: env<String>('APP_HOST'),
            port: env<int>('APP_PORT'),
            shared: env<bool>('APP_SHARED'),
          ));
      _isolates[i] = isolate;
    }
    if (env<bool>('APP_DEBUG')) {
      print("Server started on http://${env('APP_HOST')}:${env('APP_PORT')}");
    }
  }

  void killAll() {
    _isolates.forEach((int id, Isolate isolate) {
      isolate.kill();
    });
    _isolates.clear();
  }

  Future<HttpServer> startServer({
    Function? onError,
  }) async {
    await _initConfig();
    HttpServer server = await HttpServer.bind(
      env<String>('APP_HOST'),
      env<int>('APP_PORT'),
      shared: env<bool>('APP_SHARED'),
    );
    server.listen(
      (HttpRequest req) {
        httpRequestHandler(req);
      },
      onError: onError ?? (dynamic error) => print(error),
    );
    httpServer = server;

    if (env<bool>('APP_DEBUG')) {
      print("Server started on http://${env('APP_HOST')}:${env('APP_PORT')}");
    }
    return httpServer!;
  }
}
