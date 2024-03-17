import 'package:vania/src/container.dart';
import 'package:vania/src/server/base_http_server.dart';
import 'package:vania/vania.dart';

class Application extends Container {
  static Application? _singleton;

  factory Application() {
    _singleton ??= Application._internal();
    return _singleton!;
  }

  Application._internal();

  late BaseHttpServer server;

  Future<void> initialize({required Map<String, dynamic> config}) async {
    if (config['key'] == '' || config['key'] == null) {
      throw Exception('Key not found');
    }

    server = BaseHttpServer(config: config);

    if (config['isolate']) {
      server.spawnIsolates(config['isolateCount'] ?? 1);
    } else {
      server.startServer();
    }
  }

  Future<void> close() async {
    if (Config().get("isolate")) {
      server.killAll();
    } else {
      server.httpServer?.close();
    }
  }
}
