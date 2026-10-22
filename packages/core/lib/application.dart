import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'src/container.dart';
import 'src/ioc_container.dart';
import 'src/localization_handler/localization.dart';
import 'src/logger/logger.dart';
import 'src/route/route_inspector.dart' show routeDumpEnvVar;
import 'src/server/base_http_server.dart';
import 'src/server/server_isolates.dart';
import 'src/server/uncaught_errors.dart';
import 'src/env_handler/env.dart';
import 'src/http/request/request_handler.dart';
import 'src/http/session/session_manager.dart';
import 'env.dart' show env;

/// Set in the extra isolates started for `APP_ISOLATES`. Each isolate has
/// its own copy, so it stays false in the main one.
bool _isWorker = false;

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

  BaseHttpServer? _server;

  final List<_Worker> _workers = <_Worker>[];

  /// A copy of the config and setup taken before this isolate's providers
  /// boot, for starting a replacement worker later: by then the original
  /// may hold things that cannot be sent to another isolate, such as a
  /// connection.
  late final _WorkerBoot _workerBoot;

  Future<void>? _closing;

  /// Boots the app and starts serving.
  ///
  /// [setup] runs once in every isolate that serves requests, before the
  /// config's providers boot. Put there what would otherwise sit in
  /// `main()` ahead of this call — registering a database driver, an auth
  /// provider — because with `APP_ISOLATES` above 1 each extra isolate
  /// starts from scratch and never runs `main()`:
  ///
  /// ```dart
  /// await Application().initialize(
  ///   config: config,
  ///   setup: () async {
  ///     registerMySqlDriver();
  ///     await AuthServiceProvider().register(...);
  ///   },
  /// );
  /// ```
  ///
  /// It is sent to each isolate, so it must not capture anything that
  /// cannot be: an open connection or socket, say.
  Future<void> initialize({
    required Map<String, dynamic> config,
    List<String> args = const [],
    FutureOr<void> Function()? setup,
  }) async {
    keepServingOnUncaughtErrors(log: !_isWorker);
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

    // Here first, so a setup that fails stops the app before any other
    // isolate has started.
    await setup?.call();

    // Workers get the config before this isolate's providers boot, so
    // each one boots from the same untouched config.
    if (!_isWorker &&
        serverIsolateCount > 1 &&
        Platform.environment[routeDumpEnvVar] != '1') {
      await _spawnWorkers(config, args, setup);
    }

    final server = BaseHttpServer(
      config: config,
      args: args,
      isWorker: _isWorker,
    );
    _server = server;
    await server.startServer();

    if (!_isWorker) _closeOnSignals();
  }

  /// Stops every isolate's server, letting in-flight requests finish for
  /// up to `SHUTDOWN_TIMEOUT`, then writes out buffered log entries.
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    final timeout = shutdownTimeout;
    for (final worker in _workers) {
      worker.restart?.cancel();
      worker.control?.send(null);
    }
    await Future.wait([
      if (_server != null) _server!.shutdown(timeout: timeout),
      // A worker that does not answer is left to the process exit.
      for (final worker in _workers)
        worker.exited.future.timeout(
          timeout + const Duration(seconds: 1),
          onTimeout: () {},
        ),
    ]);
    await Logger.flush();
  }

  Future<void> _spawnWorkers(
    Map<String, dynamic> config,
    List<String> args,
    FutureOr<void> Function()? setup,
  ) async {
    // Sending a message copies it, even within one isolate.
    final copy = ReceivePort();
    copy.sendPort.send((config, args, setup));
    _workerBoot = await copy.first as _WorkerBoot;
    copy.close();

    for (var i = 1; i < serverIsolateCount; i++) {
      final worker = await _spawnWorker(i, const Duration(seconds: 1));
      if (worker == null) return;
      _workers.add(worker);
    }
  }

  /// Starts the server isolate for slot [index], or returns null when it
  /// cannot be started. [retryAfter] is how long to wait before replacing
  /// it should it exit.
  Future<_Worker?> _spawnWorker(int index, Duration retryAfter) async {
    final worker = _Worker(index);
    try {
      await Isolate.spawn(
        _workerMain,
        (_workerBoot, worker.ready.sendPort),
        onExit: worker.exitPort.sendPort,
        onError: worker.errors.sendPort,
        debugName: 'vania-http-$index',
      );
    } catch (e) {
      // Most likely the config or the setup holds something that cannot be
      // copied to another isolate, which every further spawn would hit as
      // well.
      worker.dispose();
      Logger.log(
        'APP_ISOLATES: could not start a server isolate ($e); '
        'serving with ${_workers.length + 1}.',
        type: Logger.WARNING,
      );
      return null;
    }
    worker.listen(onExit: () => _replace(worker, retryAfter));
    return worker;
  }

  /// Starts a new isolate in place of [worker], which exited without being
  /// asked to, after the wait [isolateRestartDelay] gives.
  void _replace(_Worker worker, Duration retryAfter) {
    if (_closing != null) return;
    final (:wait, :next) = isolateRestartDelay(
      retryAfter,
      crashedEarly: worker.uptime.elapsed < const Duration(seconds: 10),
    );
    Logger.log(
      'Server isolate vania-http-${worker.index} exited; '
      'starting a new one in ${wait.inSeconds}s.',
      type: Logger.ERROR,
    );
    worker.restart = Timer(wait, () async {
      if (_closing != null) return;
      final replacement = await _spawnWorker(worker.index, next);
      if (replacement == null) return;
      final slot = _workers.indexOf(worker);
      if (slot == -1) return;
      _workers[slot] = replacement;
    });
  }

  void _closeOnSignals() {
    final signals = [
      ProcessSignal.sigint,
      if (!Platform.isWindows) ProcessSignal.sigterm,
    ];
    for (final signal in signals) {
      signal.watch().listen((_) async {
        // A second signal while draining means: stop now.
        if (_closing != null) exit(1);
        await close();
        exit(0);
      });
    }
  }
}

/// A server isolate as seen from the main one.
class _Worker {
  /// Its slot, kept by any replacement.
  final int index;

  final Stopwatch uptime = Stopwatch()..start();

  final ReceivePort ready = ReceivePort();
  final ReceivePort exitPort = ReceivePort();
  final ReceivePort errors = ReceivePort();
  final Completer<void> exited = Completer<void>();

  /// Where the shutdown request is sent, once the isolate is serving.
  SendPort? control;

  /// The pending start of a replacement, after this one exited.
  Timer? restart;

  _Worker(this.index);

  void listen({required void Function() onExit}) {
    ready.listen((port) => control = port as SendPort);
    errors.listen((error) {
      final [message, stack] = error as List;
      Logger.log('Server isolate error: $message\n$stack', type: Logger.ERROR);
    });
    exitPort.listen((_) {
      if (!exited.isCompleted) exited.complete();
      dispose();
      onExit();
    });
  }

  void dispose() {
    ready.close();
    exitPort.close();
    errors.close();
  }
}

/// What a server isolate boots from: the config, the command-line args and
/// the app's setup.
typedef _WorkerBoot = (
  Map<String, dynamic>,
  List<String>,
  FutureOr<void> Function()?,
);

Future<void> _workerMain((_WorkerBoot, SendPort) boot) async {
  final ((config, args, setup), ready) = boot;
  _isWorker = true;

  final app = Application();
  await app.initialize(config: config, args: args, setup: setup);

  final control = ReceivePort();
  ready.send(control.sendPort);
  await control.first;
  await app._server?.shutdown(timeout: shutdownTimeout);
  await Logger.flush();
  Isolate.exit();
}
