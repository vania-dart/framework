import 'dart:io';
import 'dart:isolate';

import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/vania.dart';

import 'initialize_config.dart';
import 'isolate/isolate_handler.dart';
import 'isolate/http_isolate.dart';

class BaseHttpServer {
  final Map<String, dynamic> config;

  BaseHttpServer({required this.config});

  final _isolates = <Isolate>[];

  HttpServer? httpServer;

  void isolateEntryPoint(List<Object> args) async {
    final handler = args[0] as IsolateHandler;
    final sendPort = args[1] as SendPort;
    try {
      await httpIsolate(handler, sendPort, config);
    } catch (e, stackTrace) {
      sendPort.send(
        'Error in isolate entry point ${Isolate.current.debugName}: $e\n$stackTrace',
      );
    }
  }

  Future<void> spawnIsolates(int numIsolates) async {
    IsolateHandler isolateHandler = IsolateHandler(
      host: env<String>('APP_HOST', '127.0.0.1'),
      port: env<int>('APP_PORT', 8000),
      shared: env<bool>('APP_SHARED', false),
      secure: env<bool>('APP_SECURE', false),
      certficate: env<String>('APP_CERTIFICATE'),
      privateKey: env<String>('APP_PRIVATE_KEY'),
      privateKeyPassword: env<String>('APP_PRIVATE_KEY_PASSWORD'),
    );

    final receivePort = ReceivePort();

    for (int i = 0; i < numIsolates; i++) {
      final isolate = await Isolate.spawn(
        isolateEntryPoint,
        [isolateHandler, receivePort.sendPort],
        debugName: 'Isolate Id $i',
      );
      _isolates.add(isolate);
    }

    receivePort.listen(print);
  }

  void killAll() {
    for (Isolate isolate in _isolates) {
      isolate.kill();
    }
    _isolates.clear();
  }

  Future<HttpServer> startServer({
    Function? onError,
  }) async {
    try {
      await initializeConfig(config);
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

      httpServer?.listen(httpRequestHandler);

      if (env<bool>('APP_DEBUG')) {
        if (env<bool>('APP_SECURE')) {
          print("Server started on https://127.0.0.1:${env('APP_PORT')}");
        } else {
          print("Server started on http://127.0.0.1:${env('APP_PORT')}");
        }
      }
      return httpServer!;
    } catch (e) {
      print('Error starting server : $e');
      rethrow;
    }
  }
}
