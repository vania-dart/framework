import 'package:path/path.dart' as path;
import 'package:vm_service/vm_service.dart';

/// The small VM Service surface required by hot reload.
abstract interface class VmServiceGateway {
  Future<String?> primaryIsolateId();

  Future<bool> reloadSources(String isolateId, {required bool force});

  Future<void> dispose();
}

/// Production adapter around the Dart VM Service client.
class DartVmServiceGateway implements VmServiceGateway {
  DartVmServiceGateway(this._service);

  final VmService _service;

  @override
  Future<String?> primaryIsolateId() async {
    final vm = await _service.getVM();
    for (final isolate in vm.isolates ?? const <IsolateRef>[]) {
      if (isolate.isSystemIsolate == true || isolate.id == null) continue;
      return isolate.id;
    }
    return null;
  }

  @override
  Future<bool> reloadSources(String isolateId, {required bool force}) async {
    final report = await _service.reloadSources(isolateId, force: force);
    return report.success == true;
  }

  @override
  Future<void> dispose() => _service.dispose();
}

/// Applies an incremental VM reload for one changed Dart source.
///
/// The VM protocol has no per-file argument. With [force] disabled it checks
/// modification times and incrementally recompiles only dirty libraries and
/// the dependencies required to make the program consistent.
class HotReloadService {
  HotReloadService(this._gateway);

  final VmServiceGateway _gateway;

  Future<HotReloadResult> reloadChangedFile(String changedFile) async {
    if (path.extension(changedFile).toLowerCase() != '.dart') {
      return HotReloadResult.failure(changedFile, 'Not a Dart source file.');
    }

    final isolateId = await _gateway.primaryIsolateId();
    if (isolateId == null) {
      return HotReloadResult.failure(changedFile, 'No runnable isolate.');
    }

    final success = await _gateway.reloadSources(isolateId, force: false);
    if (!success) {
      return HotReloadResult.failure(
        changedFile,
        'The VM rejected the reload.',
      );
    }
    return HotReloadResult.success(changedFile);
  }

  Future<void> dispose() => _gateway.dispose();
}

class HotReloadResult {
  const HotReloadResult._({
    required this.changedFile,
    required this.success,
    this.message,
  });

  factory HotReloadResult.success(String changedFile) =>
      HotReloadResult._(changedFile: changedFile, success: true);

  factory HotReloadResult.failure(String changedFile, String message) =>
      HotReloadResult._(
        changedFile: changedFile,
        success: false,
        message: message,
      );

  final String changedFile;
  final bool success;
  final String? message;
}
