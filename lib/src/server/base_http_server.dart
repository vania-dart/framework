import 'dart:io';

import 'package:vania/src/config/config.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/websocket/web_socket_handler.dart';

class BaseHttpServer {
  static final BaseHttpServer _singleton = BaseHttpServer._internal();
  factory BaseHttpServer() => _singleton;
  BaseHttpServer._internal();

  late HttpServer httpServer;

  Future<HttpServer> startServer(
      {String? host, int? port, Function? onError}) async {
    host ?? '0.0.0.0';
    port ?? 8080;
    HttpServer server = await HttpServer.bind(
      host,
      port!,
      shared: true,
    );
    print("Server started on $host:$port");
    server.listen(
      (HttpRequest req) {
        if (Config().get("websocket") && req.uri.path == '/ws') {
          WebSocketHandler().handler(req);
        }
        // Handle regular HTTP requests
        if (req.uri.path != '/ws') {
          httpRequestHandler(req);
        }
      },
      onError: onError ?? (dynamic error) => print(error),
    );
    httpServer = server;
    return httpServer;
  }
}
