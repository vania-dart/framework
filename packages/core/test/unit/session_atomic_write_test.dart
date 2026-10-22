import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/session/session_file_store.dart';

/// With several server isolates there is no session cache, so every read
/// goes to the file — while another request may be writing it.
void main() {
  late Directory sandbox;
  late final SessionFileStore store;

  setUpAll(() {
    Env().load(file: File('test/.env'));
    // Read once, on first use: what turns the cache off.
    Env().env['APP_ISOLATES'] = '2';
    store = SessionFileStore();
  });

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('vania_session_atomic');
    store
      ..sessionPath = sandbox.path
      ..invalidateCache();
  });

  tearDown(() {
    store
      ..sessionPath = 'storage/framework/sessions'
      ..invalidateCache();
    sandbox.deleteSync(recursive: true);
  });

  test('a read during a write sees the whole session, old or new', () async {
    final pad = 'x' * 50000;
    await store.storeSession('sid', {'version': 0, 'pad': pad});

    final problems = <String>[];
    for (var version = 1; version <= 100; version++) {
      final write = store.storeSession('sid', {'version': version, 'pad': pad});
      final reads = [
        for (var i = 0; i < 4; i++)
          store
              .retrieveSession('sid')
              .then(
                (data) => data?['pad'] == pad ? null : 'got $data',
                onError: (Object e) => 'threw $e',
              ),
      ];
      await write;
      problems.addAll((await Future.wait(reads)).whereType<String>());
    }
    expect(problems, isEmpty);
  });

  test(
    'a session file that cannot be read is no session, not an error',
    () async {
      await store.storeSession('sid', {'user': 1});
      File(store.filePathFor('sid')).writeAsStringSync('not a session');
      store.invalidateCache();
      expect(await store.retrieveSession('sid'), isNull);
    },
  );

  test('no temporary files are left behind', () async {
    for (var i = 0; i < 10; i++) {
      await store.storeSession('sid', {'n': i});
    }
    expect(sandbox.listSync(), hasLength(1));
  });
}
