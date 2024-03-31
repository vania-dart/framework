import 'package:vania/src/container.dart';
import 'package:vania/src/server/base_http_server.dart';
import 'package:vania/vania.dart';

class Application extends Container {
  static Application? _singleton;

  factory Application() {
    _singleton ??= Application._internal();
    Env().load();
    return _singleton!;
  }

  Application._internal();

  late BaseHttpServer server;

  Future<void> initialize({required Map<String, dynamic> config}) async {
    if (env('APP_KEY') == '' || env('APP_KEY') == null) {
      throw Exception('Key not found');
    }

    server = BaseHttpServer(config: config);

    if (env('ISOLATE') != null && env<bool>('ISOLATE')) {
      server.spawnIsolates(env<int>('ISOLATE_NUMBER'));
    } else {
      server.startServer();
    }
  }

  Future<void> close() async {
    if (env<bool>('ISOLATE')) {
      server.killAll();
    } else {
      server.httpServer?.close();
    }
  }
}
