import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania_cli/service/hot_reload_service.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

void main() {
  test(
    'an actual VM observes a changed imported source without process restart',
    () async {
      final project = await Directory.systemTemp.createTemp('vania_vm_reload_');
      final mainFile = File('${project.path}/main.dart');
      final valueFile = File('${project.path}/value.dart');
      await mainFile.writeAsString('''
import 'dart:async';
import 'value.dart';

void main() {
  print('READY:${r'$'}{message()}');
  Timer.periodic(const Duration(minutes: 1), (_) {});
}
''');
      await valueFile.writeAsString("String message() => 'before';\n");

      final uriCompleter = Completer<String>();
      final readyCompleter = Completer<void>();
      final process = await Process.start(Platform.resolvedExecutable, const [
        'run',
        '--enable-vm-service=0',
        '--disable-service-auth-codes',
        'main.dart',
      ], workingDirectory: project.path);

      void inspect(String line) {
        if (line.startsWith('READY:') && !readyCompleter.isCompleted) {
          readyCompleter.complete();
        }
        if (!line.contains('VM service is listening') ||
            uriCompleter.isCompleted) {
          return;
        }
        final match = RegExp(r'https?://[^\s]+').firstMatch(line);
        if (match == null) return;
        final uri = Uri.parse(
          match.group(0)!.replaceFirst(RegExp(r'[.,]$'), ''),
        );
        final wsPath =
            uri.path.endsWith('/') ? '${uri.path}ws' : '${uri.path}/ws';
        uriCompleter.complete(
          uri.replace(scheme: 'ws', path: wsPath).toString(),
        );
      }

      final subscriptions = <StreamSubscription<String>>[
        process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(inspect),
        process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(inspect),
      ];

      VmService? vmService;
      HotReloadService? reloader;
      try {
        final uri = await uriCompleter.future.timeout(
          const Duration(seconds: 15),
        );
        await readyCompleter.future.timeout(const Duration(seconds: 15));
        vmService = await vmServiceConnectUri(uri);
        reloader = HotReloadService(DartVmServiceGateway(vmService));

        expect(await _evaluateMessage(vmService), 'before');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await valueFile.writeAsString("String message() => 'after';\n");

        final result = await reloader.reloadChangedFile('value.dart');

        expect(result.success, isTrue);
        expect(await _evaluateMessage(vmService), 'after');
        expect(process.kill(ProcessSignal.sigterm), isTrue);
      } finally {
        await reloader?.dispose();
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await project.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

Future<String?> _evaluateMessage(VmService service) async {
  final vm = await service.getVM();
  final isolate = (vm.isolates ?? const <IsolateRef>[]).firstWhere(
    (candidate) => candidate.isSystemIsolate != true,
  );
  final isolateId = isolate.id!;
  final details = await service.getIsolate(isolateId);
  final libraryId = details.rootLib!.id!;
  final response = await service.evaluate(isolateId, libraryId, 'message()');
  return response is InstanceRef ? response.valueAsString : null;
}
