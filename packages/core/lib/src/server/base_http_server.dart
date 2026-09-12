import 'dart:io';
import '../route/route_inspector.dart';
import 'package:args/args.dart';
import 'package:vania/src/http/request/request_handler.dart';

import 'package:vania/env.dart' show env;
import '../ioc_container.dart';
import 'initialize_config.dart';

class BaseHttpServer {
  final Map<String, dynamic> config;
  final List<String> args;

  BaseHttpServer({required this.config, this.args = const []});

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

  Future<HttpServer> startServer({Function? onError}) async {
    String host = env<String>('APP_HOST', InternetAddress.anyIPv6.host);
    int port = env<int>('APP_PORT', 8000);

    if (args.isNotEmpty) {
      final parser = ArgParser()
        ..addOption('host', abbr: 'h')
        ..addOption('port', abbr: 'p');

      ArgResults results;
      try {
        results = parser.parse(args);
      } on ArgParserException catch (e) {
        stderr.writeln('Error: ${e.message}\n');
        stderr.writeln(parser.usage);
        exit(64);
      }

      if (results['host'] != null) {
        host = results['host'];
      }

      if (results['port'] != null) {
        port = int.tryParse(results['port']) ?? 8000;
      }
    }
    try {
      await initializeConfig(config);

      // `vania route:list` boots the app this far and reads the routing
      // table, so what it prints is what the app would actually serve.
      dumpRoutesIfRequested();

      if (env<bool>('APP_SECURE', false)) {
        String certificateChain = env<String>('APP_CERTIFICATE');
        String serverKey = env<String>('APP_PRIVATE_KEY');
        String password = env<String>('APP_PRIVATE_KEY_PASSWORD');

        SecurityContext context = SecurityContext()
          ..useCertificateChain(certificateChain)
          ..usePrivateKey(serverKey, password: password);

        httpServer = await HttpServer.bindSecure(
          host,
          port,
          context,
          shared: env<bool>('APP_SHARED', false),
        );
      } else {
        httpServer = await HttpServer.bind(
          host,
          port,
          shared: env<bool>('APP_SHARED', false),
        );
      }

      httpServer?.listen(IoCContainer().resolve<RequestHandler>().handle);

      if (env<bool>('APP_DEBUG')) {
        stderr.writeln('Server started on http://127.0.0.1:$port');
      }
      return httpServer!;
    } catch (e) {
      stderr.writeln('${DateTime.now().toUtc()} ERROR: $e');
      rethrow;
    }
  }
}
