import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:vm_service/vm_service_io.dart';
import 'package:watcher/watcher.dart';

import '../common/console.dart';
import '../service/hot_reload_service.dart';
import '../utils/functions.dart';
import 'command.dart';
import 'route_list_command.dart';

/// Runs the development server with incremental VM hot reload.
class ServeCommand extends Command {
  @override
  String get name => 'serve';

  @override
  String get description => 'Run the app and hot reload changed Dart sources';

  @override
  String get usage =>
      '[--host <host>] [--port <port>] [--no-reload] [--no-watch]';

  @override
  String get help => '''
Keys while running:
  r   hot reload         re-compile changed libraries in place
  R   restart            start the process again from scratch
  l   list routes        print the routing table
  c   clear              clear the screen
  q   quit               stop the server and exit

Options:
  --host <host>   host to bind (overrides APP_HOST)
  --port <port>   port to bind (overrides APP_PORT)
  --no-reload     restart the process on change instead of hot reloading
  --no-watch      do not watch for file changes at all''';

  Process? _process;
  HotReloadService? _hotReload;
  Timer? _debounce;
  StreamSubscription<WatchEvent>? _watchSubscription;
  StreamSubscription<List<int>>? _keySubscription;
  StreamSubscription<ProcessSignal>? _signalSubscription;
  final Set<String> _changedFiles = <String>{};
  final Completer<int> _completion = Completer<int>();
  bool _reloading = false;
  bool _restarting = false;
  bool _shuttingDown = false;

  static const String _manualReloadMarker = 'lib/.manual_reload.dart';

  @override
  Future<int> execute(List<String> arguments) async {
    final entrypoint = File('${workingDirectory.path}/bin/server.dart');
    if (!entrypoint.existsSync()) {
      Console.error('bin/server.dart does not exist.');
      return ExitCode.noInput;
    }

    final options = _ServeOptions.parse(arguments);
    if (options == null) return ExitCode.usage;
    if (!await _startProcess(options)) return ExitCode.failure;

    if (options.watch) _startWatcher(options);
    _bindKeys(options);
    _bindInterrupt();
    _printBanner(options);
    return _completion.future;
  }

  Future<bool> _startProcess(_ServeOptions options) async {
    final serviceUri = options.reload ? Completer<String>() : null;
    final arguments = <String>['run'];
    if (options.reload) {
      arguments.addAll(const [
        '--enable-vm-service=0',
        '--disable-service-auth-codes',
      ]);
    }
    arguments
      ..add(path.normalize('bin/server.dart'))
      ..addAll(options.passthrough);

    final Process process;
    try {
      process = await Process.start(
        'dart',
        arguments,
        workingDirectory: workingDirectory.path,
      );
    } on ProcessException catch (error) {
      Console.error('Could not start the server: ${error.message}');
      return false;
    }

    _process = process;
    _pipeOutput(process, serviceUri);
    _observeUnexpectedExit(process);
    await _recordPid(process.pid);

    if (serviceUri == null) return true;
    try {
      final uri = await serviceUri.future.timeout(const Duration(seconds: 15));
      final service = await vmServiceConnectUri(uri);
      _hotReload = HotReloadService(DartVmServiceGateway(service));
    } on TimeoutException {
      Console.warn(
        'VM Service did not become ready; file changes will restart the app.',
      );
    } catch (error) {
      Console.warn(
        'Could not connect to VM Service ($error); file changes will restart '
        'the app.',
      );
    }
    return true;
  }

  void _pipeOutput(Process process, Completer<String>? serviceUri) {
    void forward(String line) {
      if (line.isEmpty) return;
      if (serviceUri != null && !serviceUri.isCompleted) {
        final uri = _extractVmServiceUri(line);
        if (uri != null) serviceUri.complete(uri);
      }
      Console.line(line);
    }

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(forward);
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(forward);
  }

  static String? _extractVmServiceUri(String line) {
    if (!line.contains('VM service is listening')) return null;
    final match = RegExp(r'https?://[^\s]+').firstMatch(line);
    if (match == null) return null;

    final uri = Uri.parse(match.group(0)!.replaceFirst(RegExp(r'[.,]$'), ''));
    final websocketPath =
        uri.path.endsWith('/') ? '${uri.path}ws' : '${uri.path}/ws';
    return uri.replace(scheme: 'ws', path: websocketPath).toString();
  }

  void _observeUnexpectedExit(Process process) {
    unawaited(() async {
      final code = await process.exitCode;
      if (_process != process || _restarting || _shuttingDown) return;
      _process = null;
      if (!_completion.isCompleted) {
        _completion.complete(code == 0 ? ExitCode.success : ExitCode.failure);
      }
    }());
  }

  void _startWatcher(_ServeOptions options) {
    final sourceDirectory = path.join(workingDirectory.path, 'lib');
    final watcher = DirectoryWatcher(sourceDirectory);
    _watchSubscription = watcher.events.listen((event) {
      if (path.extension(event.path).toLowerCase() != '.dart') return;

      _changedFiles.add(path.relative(event.path, from: workingDirectory.path));
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 250),
        () => unawaited(_applyPendingChanges(options)),
      );
    });
  }

  Future<void> _applyPendingChanges(_ServeOptions options) async {
    if (_reloading || _changedFiles.isEmpty || _shuttingDown) return;
    _reloading = true;
    try {
      while (_changedFiles.isNotEmpty && !_shuttingDown) {
        final files = Set<String>.from(_changedFiles);
        _changedFiles.clear();
        for (final file in files.where((file) => file != _manualReloadMarker)) {
          Console.info(Console.cyan('~ $file'));
        }

        final hotReload = _hotReload;
        if (!options.reload || hotReload == null) {
          await _restartProcess(options);
          continue;
        }

        final stopwatch = Stopwatch()..start();
        try {
          final result = await hotReload
              .reloadChangedFile(files.first)
              .timeout(const Duration(seconds: 15));
          if (!result.success) {
            Console.warn(
              '${result.message ?? 'Hot reload failed.'} Press R to restart.',
            );
            continue;
          }
          final automaticCount =
              files.where((file) => file != _manualReloadMarker).length;
          final subject =
              automaticCount == 0
                  ? 'Reloaded'
                  : 'Reloaded $automaticCount changed file(s)';
          Console.success(
            '$subject ${Console.dim('(${stopwatch.elapsedMilliseconds}ms)')}',
          );
        } catch (error) {
          Console.warn('Hot reload failed ($error); restarting.');
          await _restartProcess(options);
        }
      }
    } finally {
      _reloading = false;
      if (_changedFiles.isNotEmpty && !_shuttingDown) {
        unawaited(_applyPendingChanges(options));
      }
    }
  }

  Future<void> _restartProcess(_ServeOptions options) async {
    if (_restarting || _shuttingDown) return;
    _restarting = true;
    try {
      Console.info('Restarting…');
      await _stopProcess();
      if (await _startProcess(options)) {
        Console.success('Restarted');
      } else {
        Console.error('Restart failed.');
      }
    } finally {
      _restarting = false;
    }
  }

  void _bindKeys(_ServeOptions options) {
    if (!stdin.hasTerminal) return;
    stdin
      ..echoMode = false
      ..lineMode = false;

    _keySubscription = stdin.listen((bytes) {
      if (bytes.isEmpty) return;
      switch (String.fromCharCode(bytes.first)) {
        case 'r':
          _changedFiles.add(_manualReloadMarker);
          unawaited(_applyPendingChanges(options));
        case 'R':
          unawaited(_restartProcess(options));
        case 'l':
          unawaited(_printRoutes());
        case 'c':
          Console.clear();
        case 'q':
          unawaited(_finish(ExitCode.success));
      }
    });
  }

  void _bindInterrupt() {
    try {
      _signalSubscription = ProcessSignal.sigint.watch().listen((_) {
        unawaited(_finish(ExitCode.success));
      });
    } on UnsupportedError {
      // Signal streams are not available on every platform.
    }
  }

  Future<void> _printRoutes() async {
    Console.line();
    final command = RouteListCommand()..workingDirectory = workingDirectory;
    await command.execute(const []);
    Console.line();
  }

  Future<void> _finish(int code) async {
    if (_shuttingDown) return;
    _shuttingDown = true;
    Console.info('Stopping…');
    _debounce?.cancel();
    await _watchSubscription?.cancel();
    await _keySubscription?.cancel();
    await _signalSubscription?.cancel();
    if (stdin.hasTerminal) {
      stdin
        ..echoMode = true
        ..lineMode = true;
    }
    await _stopProcess();
    if (!_completion.isCompleted) _completion.complete(code);
  }

  Future<void> _stopProcess() async {
    await _hotReload?.dispose();
    _hotReload = null;

    final process = _process;
    _process = null;
    if (process == null) return;
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
  }

  Future<void> _recordPid(int pid) async {
    final config = await getDartToolVaniaConfig(
      workingDirectory: workingDirectory,
    );
    if (config == null) return;
    config['process'] = {'pid': pid};
    await updateDartToolVaniaConfig(config, workingDirectory: workingDirectory);
  }

  void _printBanner(_ServeOptions options) {
    Console.line();
    Console.info(Console.bold('Vania dev server'));
    final status =
        !options.watch
            ? 'File watching disabled — r reload, R restart, l routes, q quit'
            : options.reload
            ? 'Watching for changes — r reload, R restart, l routes, q quit'
            : 'Restarting on changes — R restart, l routes, q quit';
    Console.info(Console.dim(status));
    Console.line();
  }
}

class _ServeOptions {
  const _ServeOptions({
    required this.reload,
    required this.watch,
    required this.passthrough,
  });

  final bool reload;
  final bool watch;
  final List<String> passthrough;

  static _ServeOptions? parse(List<String> arguments) {
    var reload = true;
    var watch = true;
    final passthrough = <String>[];

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--no-reload') {
        reload = false;
        continue;
      }
      if (argument == '--no-watch') {
        watch = false;
        continue;
      }
      if (argument == '--vm') continue;
      if (argument == '--host' ||
          argument == '-h' ||
          argument == '--port' ||
          argument == '-p') {
        if (index + 1 >= arguments.length) {
          Console.error('$argument needs a value.');
          return null;
        }
        passthrough
          ..add(argument)
          ..add(arguments[++index]);
        continue;
      }
      Console.error('Unknown option: $argument');
      return null;
    }

    return _ServeOptions(
      reload: reload,
      watch: watch,
      passthrough: passthrough,
    );
  }
}
