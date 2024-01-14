import 'dart:io';

import 'package:vania/src/config/config.dart';
import 'package:vania/src/http/request/request_handler.dart';

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
        if (Config().get("websocket")) {
          if (req.uri.path == '/ws') {
            // Upgrade an HttpRequest to a WebSocket connection
            WebSocketTransformer.upgrade(req).then((WebSocket socket) {
              print('WebSocket client connected!');

              // Listen for incoming messages from the WebSocket client
              socket.listen((message) {
                print('Received message from WebSocket client: $message');
                socket.add('You sent to WebSocket: $message');
              });
            });
          }
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
