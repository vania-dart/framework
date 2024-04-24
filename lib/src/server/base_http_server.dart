import 'dart:io';
import 'dart:isolate';

import 'package:eloquent/eloquent.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/vania.dart';

class IsolateHandler {
  final String host;
  final int port;
  final bool shared;
  final bool secure;
  final String? certficate;
  final String? privateKey;
  final String? privateKeyPassword;
  const IsolateHandler({
    required this.host,
    required this.port,
    required this.shared,
    this.secure = false,
    this.certficate,
    this.privateKey,
    this.privateKeyPassword,
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

    if (handler.secure) {
      var context = SecurityContext()
        ..useCertificateChain(handler.certficate ?? '')
        ..usePrivateKey(
          handler.privateKey ?? '',
          password: handler.privateKeyPassword,
        );

      httpServer = await HttpServer.bindSecure(
        handler.host,
        handler.port,
        context,
        shared: handler.shared,
      );
    } else {
      httpServer = await HttpServer.bind(
        handler.host,
        handler.port,
        shared: handler.shared,
      );
    }

    httpServer?.listen(
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
            host: env<String>('APP_HOST', '127.0.0.1'),
            port: env<int>('APP_PORT', 8000),
            shared: env<bool>('APP_SHARED', false),
            secure: env<bool>('APP_SECURE', false),
            certficate: env<String>('APP_CERTIFICATE'),
            privateKey: env<String>('APP_PRIVATE_KEY'),
            privateKeyPassword: env<String>('APP_PRIVATE_KEY_PASSWORD'),
          ));
      _isolates[i] = isolate;
    }
    if (env<bool>('APP_DEBUG')) {
      if (env<bool>('APP_SECURE', false)) {
        print("Server started on https://127.0.0.1:${env('APP_PORT', 8000)}");
      } else {
        print("Server started on http://127.0.0.1:${env('APP_PORT', 8000)}");
      }
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
    if (env<bool>('APP_SECURE', false)) {
      var certificateChain = env<String>('APP_CERTIFICATE');
      var serverKey = env<String>('APP_PRIVATE_KEY');
      var password = env<String>('APP_PRIVATE_KEY_PASSWORD');

      var context = SecurityContext()
        ..useCertificateChain(certificateChain)
        ..usePrivateKey(serverKey, password: password);

      httpServer = await HttpServer.bindSecure(
        env<String>('APP_HOST', '127.0.0.1'),
        env<int>('APP_PORT', 8000),
        context,
        shared: env<bool>('APP_SHARED', false),
      );
    } else {
      httpServer = await HttpServer.bind(
        env<String>('APP_HOST', '127.0.0.1'),
        env<int>('APP_PORT', 8000),
        shared: env<bool>('APP_SHARED', false),
      );
    }

    httpServer?.listen(
      (HttpRequest req) {
        httpRequestHandler(req);
      },
      onError: onError ?? (dynamic error) => print(error),
    );

    if (env<bool>('APP_DEBUG')) {
      if (env<bool>('APP_SECURE')) {
        print("Server started on https://127.0.0.1:${env('APP_PORT')}");
      } else {
        print("Server started on http://127.0.0.1:${env('APP_PORT')}");
      }
    }
    return httpServer!;
  }
}
