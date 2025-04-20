import 'dart:io';

import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/vania.dart';

import '../ioc_container.dart';
import 'initialize_config.dart';

class BaseHttpServer {
  final Map<String, dynamic> config;

  BaseHttpServer({required this.config});

  HttpServer? httpServer;

  /// Starts the HTTP server with the current configuration.
  ///
  /// If the application is configured to use a secure connection, the server
  /// will be started using HTTPS with the provided certificate and private key.
  /// Otherwise, it will start an HTTP server.
  ///
  /// The server listens for incoming HTTP requests using the `httpRequestHandler`.
  ///
  /// If the `APP_DEBUG` environment variable is set to true, the server's URL
  /// will be printed to the console.
  ///
  /// An optional [onError] callback can be provided to handle server start errors.
  ///
  /// Returns a [Future] that completes with the started [HttpServer] instance.
  ///
  /// Throws an error if the server fails to start.

  Future<HttpServer> startServer({
    Function? onError,
  }) async {
    try {
      await initializeConfig(config);
      if (env<bool>('APP_SECURE', false)) {
        String certificateChain = env<String>('APP_CERTIFICATE');
        String serverKey = env<String>('APP_PRIVATE_KEY');
        String password = env<String>('APP_PRIVATE_KEY_PASSWORD');

        SecurityContext context = SecurityContext()
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

      httpServer?.listen(IoCContainer().resolve<RequestHandler>().handle);

      if (env<bool>('APP_DEBUG')) {
        stderr.writeln('Server started on http://127.0.0.1:${env('APP_PORT')}');
      }
      return httpServer!;
    } catch (e) {
      stderr.writeln('${DateTime.now().toUtc()} ERROR: $e');
      rethrow;
    }
  }
}
