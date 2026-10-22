import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/session/session_file_store.dart';

void main() {
  late Directory sandbox;

  setUp(() {
    Env().load(file: File('test/.env'));
    // Read once, on first use, so it is set before anything reads it.
    Env().env['APP_ISOLATES'] = '2';
    sandbox = Directory.systemTemp.createTempSync('vania_session_isolates');
    SessionFileStore()
      ..sessionPath = sandbox.path
      ..invalidateCache();
  });

  tearDown(() {
    SessionFileStore()
      ..sessionPath = 'storage/framework/sessions'
      ..invalidateCache();
    sandbox.deleteSync(recursive: true);
  });

  test('with several server isolates, sessions are always read from disk, '
      'so a change made by another isolate is seen', () async {
    final store = SessionFileStore();
    await store.storeSession('sid', {'user': 'a'});
    expect(store.cacheSize, 0);

    // What another isolate's write looks like from here: the file changes
    // and this isolate is not told.
    final other = File(store.filePathFor('sid'));
    final before = other.readAsStringSync();
    await store.storeSession('sid', {'user': 'b'});
    final after = other.readAsStringSync();
    other.writeAsStringSync(before);
    expect(await store.retrieveSession('sid'), {'user': 'a'});
    other.writeAsStringSync(after);
    expect(await store.retrieveSession('sid'), {'user': 'b'});
  });
}
