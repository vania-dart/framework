import 'dart:io';
import 'dart:isolate';

import 'package:vania/src/config/config.dart';
import 'package:vania/src/http/request/request_handler.dart';

class BaseHttpServer {
  static final BaseHttpServer _singleton = BaseHttpServer._internal();
  factory BaseHttpServer() => _singleton;
  BaseHttpServer._internal();

  List<Isolate> isolates = [];

  HttpServer? httpServer;

  void startIsolatedServer(SendPort sendPort) async {
    print( Config().get('host') );
    var server = await HttpServer.bind(
      Config().get('host') ?? '0.0.0.0',
      Config().get('port') ?? 8080,
      shared: true,
    );
    print("Server started on https://127.0.0.1:8000");

    await for (HttpRequest request in server) {
      httpRequestHandler(request);
    }
  }

  Future<void> spawnIsolates(int count) async {
    for (int i = 0; i < count; i++) {
      print('Started Isload $i');
      Isolate isolate =
          await Isolate.spawn(startIsolatedServer, ReceivePort().sendPort);
      isolates.add(isolate);
    }
  }

  void killAllIsolates() {
    for (var isolate in isolates) {
      isolate.kill(priority: Isolate.immediate);
    }
    isolates.clear();
  }

  Future<HttpServer> startServer(
      {String? host, int? port, Function? onError}) async {
    host ?? '0.0.0.0';
    port ?? 8080;
    HttpServer server = await HttpServer.bind(
      host,
      port!,
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
      print("Server started on http://$host:$port");
    }
    return httpServer!;
  }
}
