import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/session/session_file_store.dart';

void main() {
  group('SessionFileStore in-memory cache', () {
    late Directory tempSessionDir;

    setUp(() async {
      Env().load(file: File('test/.env'));
      tempSessionDir = Directory('storage/framework/sessions');
      await tempSessionDir.create(recursive: true);
      SessionFileStore().invalidateCache();
    });

    test(
      'second retrieve returns cached data even after the file is deleted',
      () async {
        const sid = 'test-session-cache-hit';
        await SessionFileStore().storeSession(sid, {'k': 'v1'});

        final first = await SessionFileStore().retrieveSession(sid);
        expect(first?['k'], equals('v1'));

        final store = SessionFileStore();
        final path = store.filePathFor(sid);
        final file = File(path);
        if (await file.exists()) await file.delete();

        final second = await SessionFileStore().retrieveSession(sid);
        expect(second?['k'], equals('v1'));
      },
    );

    test(
      'deleteSession invalidates the cache so future retrieves miss',
      () async {
        const sid = 'test-session-invalidate';
        await SessionFileStore().storeSession(sid, {'k': 'v1'});
        expect(
          (await SessionFileStore().retrieveSession(sid))?['k'],
          equals('v1'),
        );

        await SessionFileStore().deleteSession(sid);
        final after = await SessionFileStore().retrieveSession(sid);
        expect(after == null || after.isEmpty, isTrue);
      },
    );

    test(
      'cache eviction keeps the store bounded (does not grow without bound)',
      () async {
        Env().env['SESSION_CACHE_SIZE'] = '50';
        SessionFileStore().invalidateCache();
        for (var i = 0; i < 60; i++) {
          await SessionFileStore().storeSession('sid-$i', {'i': i});
        }
        expect(SessionFileStore().cacheSize, lessThanOrEqualTo(50));
      },
    );

    tearDown(() async {
      SessionFileStore().invalidateCache();
      Env().env.remove('SESSION_CACHE_SIZE');
    });
  });
}
