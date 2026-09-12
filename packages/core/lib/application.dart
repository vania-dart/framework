import 'src/container.dart';
import 'src/ioc_container.dart';
import 'src/localization_handler/localization.dart';
import 'src/server/base_http_server.dart';
import 'src/env_handler/env.dart';
import 'src/http/request/request_handler.dart';
import 'src/http/session/session_manager.dart';
import 'env.dart' show env;

class Application extends Container {
  static Application? _singleton;

  factory Application() {
    if (_singleton == null) {
      _singleton = Application._internal();
      Env().load();
    }
    return _singleton!;
  }

  Application._internal();

  late BaseHttpServer _server;

  Future<void> initialize({
    required Map<String, dynamic> config,
    List<String> args = const [],
  }) async {
    await Localization().init();

    IoCContainer().register<RequestHandler>(() => RequestHandler());
    IoCContainer().register<SessionManager>(
      () => SessionManager(),
      singleton: true,
    );

    // APP_KEY keys session encryption and the framework's HMACs, so a
    // short one weakens both. 32 characters is the minimum.
    final appKey = env('APP_KEY');
    if (appKey == null || appKey is! String || appKey.length < 32) {
      throw Exception(
        'APP_KEY missing or too short (must be at least 32 characters). '
        'Generate one with `openssl rand -base64 32` and add it to .env',
      );
    }

    _server = BaseHttpServer(config: config, args: args);
    _server.startServer();
  }

  Future<void> close() async {
    _server.httpServer?.close();
  }
}
