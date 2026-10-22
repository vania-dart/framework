import 'dart:async';
import 'dart:io';
import '../route/route_inspector.dart';
import 'package:args/args.dart';
import 'package:vania/src/http/request/request_handler.dart';

import 'package:vania/env.dart' show env;
import '../ioc_container.dart';
import '../logger/logger.dart';
import 'initialize_config.dart';
import 'server_isolates.dart';

class BaseHttpServer {
  final Map<String, dynamic> config;
  final List<String> args;

  /// True in the extra isolates started for `APP_ISOLATES`, which serve
  /// alongside the main one and so do not announce themselves.
  final bool isWorker;

  BaseHttpServer({
    required this.config,
    this.args = const [],
    this.isWorker = false,
  });

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

      // Isolates serving the same port must all bind it shared.
      final shared = env<bool>('APP_SHARED', false) || serverIsolateCount > 1;

      // Connections the OS queues while the server is busy accepting. A
      // burst beyond it is refused, so the OS's own default — often 128 —
      // is too small for real traffic. The OS caps it in turn
      // (`net.core.somaxconn` on Linux, `kern.ipc.somaxconn` on macOS).
      final backlog = env<int>('HTTP_BACKLOG', 1024);

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
          backlog: backlog,
          shared: shared,
        );
      } else {
        httpServer = await HttpServer.bind(
          host,
          port,
          backlog: backlog,
          shared: shared,
        );
      }

      // Seconds an idle keep-alive connection is held open; 0 never
      // closes it. 120 matches dart:io's own default.
      final idleSeconds = env<int>('HTTP_IDLE_TIMEOUT', 120);
      httpServer!.idleTimeout = idleSeconds > 0
          ? Duration(seconds: idleSeconds)
          : null;

      httpServer?.listen(
        IoCContainer().resolve<RequestHandler>().handle,
        // An unhandled error on the server stream would stop the isolate;
        // a single bad connection is not worth that.
        onError: (Object e, StackTrace stack) =>
            Logger.log('HTTP server error: $e\n$stack', type: Logger.ERROR),
      );

      if (!isWorker && env<bool>('APP_DEBUG')) {
        final isolates = serverIsolateCount > 1
            ? ' ($serverIsolateCount isolates)'
            : '';
        stderr.writeln('Server started on http://127.0.0.1:$port$isolates');
      }
      return httpServer!;
    } catch (e) {
      stderr.writeln('${DateTime.now().toUtc()} ERROR: $e');
      rethrow;
    }
  }

  /// Stops accepting connections and lets in-flight requests finish.
  ///
  /// Idle keep-alive connections close at once and busy ones as soon as
  /// their response completes. Whatever is still open after [timeout] —
  /// a stalled client, a long-lived stream — is closed regardless.
  Future<void> shutdown({required Duration timeout}) async {
    final server = httpServer;
    if (server == null) return;

    unawaited(server.close());
    final waited = Stopwatch()..start();
    while (server.connectionsInfo().total > 0 && waited.elapsed < timeout) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await server.close(force: true);
  }
}
