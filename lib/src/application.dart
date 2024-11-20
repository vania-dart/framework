import 'dart:io';

import 'package:vaniaFramework/src/container.dart';
import 'package:vaniaFramework/src/localization_handler/localization.dart';
import 'package:vaniaFramework/src/server/base_http_server.dart';
import 'package:vaniaFramework/vania_framework.dart';

class Application extends Container {
  static Application? _singleton;

  factory Application() {
    if (_singleton == null) {
      _singleton = Application._internal();
      // Env().load();
      Localization().init();
    }
    return _singleton!;
  }

  Application._internal();

  late BaseHttpServer server;

  Future<void> initialize({required Map<String, dynamic> config}) async {
    final String appKeyValue = Platform.environment['APP_KEY'] ?? "";
    if (appKeyValue == '' ||  appKeyValue == null) {
      throw Exception('Key not found');
    }

    server = BaseHttpServer(config: config);
    final bool isolateStatus = bool.tryParse(Platform.environment['ISOLATE'] ?? 'false') ?? false;
    if (isolateStatus) {
      final isolatesNumber =  int.tryParse(Platform.environment['ISOLATE_NUMBER'] ?? '1') ?? 1;
      await server.spawnIsolates(isolatesNumber);
    } else {
      server.startServer();
    }
  }

  Future<void> close() async {
    final bool isolateStatus = bool.tryParse(Platform.environment['ISOLATE'] ?? 'false') ?? false;
    if (isolateStatus) {
      server.killAll();
    } else {
      server.httpServer?.close();
    }
  }
}
