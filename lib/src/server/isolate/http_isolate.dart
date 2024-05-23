import 'dart:io';
import 'dart:isolate';

import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/vania.dart';

import '../initialize_config.dart';
import 'isolate_handler.dart';

Future<void> httpIsolate(
  IsolateHandler handler,
  SendPort sendPort,
  Map config,
) async {

  try {
    await initializeConfig(config);
    Env().load();
    HttpServer server;
    if (handler.secure) {
      var context = SecurityContext()
        ..useCertificateChain(handler.certficate ?? '')
        ..usePrivateKey(
          handler.privateKey ?? '',
          password: handler.privateKeyPassword,
        );

      server = await HttpServer.bindSecure(
        handler.host,
        handler.port,
        context,
        shared: handler.shared,
      );
    } else {
      server = await HttpServer.bind(
        handler.host,
        handler.port,
        shared: handler.shared,
      );
    }
    sendPort.send(
      'Server running on ${server.address.address}:${server.port} in ${Isolate.current.debugName}',
    );
    server.listen(httpRequestHandler);
  } catch (e, stackTrace) {
    sendPort.send(
      'Error starting server in ${Isolate.current.debugName}: $e\n$stackTrace',
    );
  }
  
}
