import 'dart:io';
import 'dart:isolate';

import 'package:vaniaFramework/src/http/request/request_handler.dart';
import 'package:vaniaFramework/vania_framework.dart';
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
      host: Platform.environment['APP_HOST'] ??  '0.0.0.0',
      port: int.parse(Platform.environment['PORT'] ?? '8080'),
      shared: bool.parse((Platform.environment['APP_SHARED'] ??  'false')) ,
      secure:  bool.parse(Platform.environment['APP_SECURE'] ??  'false'),
      certficate: Platform.environment['APP_CERTIFICATE'],
      privateKey: Platform.environment['APP_PRIVATE_KEY'],
      privateKeyPassword: Platform.environment['APP_PRIVATE_KEY_PASSWORD'] ,
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
      final bool appSecureStatus = bool.tryParse(Platform.environment['APP_SECURE'] ?? 'false') ?? false ;
      if (appSecureStatus) {
        var certificateChain = Platform.environment['APP_CERTIFICATE'] ??  env<String>('APP_CERTIFICATE');
        var serverKey = Platform.environment['APP_PRIVATE_KEY'] ?? env<String>('APP_PRIVATE_KEY');
        var password =  Platform.environment['APP_PRIVATE_KEY_PASSWORD'] ?? env<String>('APP_PRIVATE_KEY_PASSWORD');

        var context = SecurityContext()
          ..useCertificateChain(certificateChain)
          ..usePrivateKey(serverKey, password: password);
        final port = int.parse(Platform.environment['PORT'] ?? '8080');
        httpServer = await HttpServer.bindSecure(
          Platform.environment['APP_HOST'] ??  '0.0.0.0',
          port,
          context,
          shared: bool.parse(Platform.environment['APP_SHARED'] ?? 'false'),
        );
      } else {
        final port = int.parse(Platform.environment['PORT'] ?? '8080');
        httpServer = await HttpServer.bind(
          // InternetAddress.anyIPv6.host,
          Platform.environment['APP_HOST'] ??  '0.0.0.0'
          port,
          shared: bool.parse(Platform.environment['APP_SHARED'] ?? 'false'),
        );
      }

      httpServer?.listen(httpRequestHandler);
      final bool appDebugStatus = bool.tryParse(Platform.environment['APP_DEBUG'] ?? 'false') ?? false;

      if (appDebugStatus) {
        final bool appSecureStatus =  bool.tryParse(Platform.environment['APP_SECURE'] ?? 'false') ?? false;
        final port = int.parse(Platform.environment['PORT'] ?? '8080');

        if (appSecureStatus) {
          print("Server started on https://127.0.0.1:$port");
        } else {
          print("Server started on http://127.0.0.1:$port");
        }
      }
      return httpServer!;
    } catch (e) {
      print('Error starting server : $e');
      rethrow;
    }
  }
}
