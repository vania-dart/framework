import 'package:test/test.dart';
import 'package:vania_cli/service/hot_reload_service.dart';

class _Gateway implements VmServiceGateway {
  _Gateway({this.isolateId = 'isolate-1', this.success = true});

  final String? isolateId;
  final bool success;
  final List<({String isolateId, bool force})> calls = [];
  var disposed = false;

  @override
  Future<String?> primaryIsolateId() async => isolateId;

  @override
  Future<bool> reloadSources(String isolateId, {required bool force}) async {
    calls.add((isolateId: isolateId, force: force));
    return success;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test(
    'reloads changed sources once without forcing the whole project',
    () async {
      final gateway = _Gateway();
      final reloader = HotReloadService(gateway);

      final result = await reloader.reloadChangedFile('lib/users/user.dart');

      expect(result.success, isTrue);
      expect(result.changedFile, 'lib/users/user.dart');
      expect(gateway.calls, [(isolateId: 'isolate-1', force: false)]);
    },
  );

  test('rejects non-Dart changes without asking the VM to reload', () async {
    final gateway = _Gateway();
    final reloader = HotReloadService(gateway);

    final result = await reloader.reloadChangedFile('lib/users/readme.md');

    expect(result.success, isFalse);
    expect(gateway.calls, isEmpty);
  });

  test('reports failure when no runnable isolate exists', () async {
    final gateway = _Gateway(isolateId: null);
    final reloader = HotReloadService(gateway);

    final result = await reloader.reloadChangedFile('lib/users/user.dart');

    expect(result.success, isFalse);
    expect(gateway.calls, isEmpty);
  });

  test('reports a reload rejected by the VM', () async {
    final gateway = _Gateway(success: false);
    final reloader = HotReloadService(gateway);

    final result = await reloader.reloadChangedFile('lib/users/user.dart');

    expect(result.success, isFalse);
    expect(gateway.calls, hasLength(1));
  });
}
