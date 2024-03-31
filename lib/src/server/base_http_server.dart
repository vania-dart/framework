import 'dart:io';
import 'dart:isolate';

import 'package:eloquent/eloquent.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/vania.dart';

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

    Env().load();

    try {
      DatabaseConfig? db = Config().get('database');
      if (db != null) {
        await db.driver?.init(Config().get('database'));
      }
    } on InvalidArgumentException catch (e) {
       Logger.log(e.toString(), type: Logger.ERROR);
      rethrow;
    }
  }

  void startIsolatedServer(SendPort sendPort) async {
    await _initConfig();
    var server = await HttpServer.bind(
      Config().get('host') ?? '0.0.0.0',
      Config().get('port') ?? 8080,
      shared: true,
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
      Isolate isolate =
          await Isolate.spawn(startIsolatedServer, ReceivePort().sendPort);
      _isolates[i] = isolate;
    }
    if (config['debug']) {
      print("Server started on http://127.0.0.1:${config['port']}");
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
      config['host'] ?? '0.0.0.0',
      config['port'] ?? 8080,
      shared: true,
    );
    server.listen(
      (HttpRequest req) {
        httpRequestHandler(req);
      },
      onError: onError ?? (dynamic error) => print(error),
    );
    httpServer = server;

    if (Config().get("debug")) {
      print("Server started on http://${config['host']}:${config['port']}");
    }
    return httpServer!;
  }
}
