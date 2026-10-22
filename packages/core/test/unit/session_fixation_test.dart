import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/http/session/session_file_store.dart';
import 'package:vania/src/http/session/session_manager.dart';

/// Serves one request with [handler] inside a started session, and
/// returns the session id the response hands the browser.
Future<String> _visit(
  String sessionId,
  Future<void> Function(SessionManager sessions) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) {
    runInRequestScope(req, () async {
      final sessions = SessionManager();
      await sessions.sessionStart(req, req.response);
      await handler(sessions);
      await Response.json({}).makeResponse(req.response);
    });
  });
  final client = HttpClient();
  final rq = await client.get('127.0.0.1', server.port, '/');
  rq.cookies.add(Cookie(SessionManager().sessionKey, sessionId));
  final res = await rq.close();
  await res.drain<void>();
  client.close(force: true);
  await server.close(force: true);
  return res.cookies
      .lastWhere((c) => c.name == SessionManager().sessionKey)
      .value;
}

void main() {
  late Directory sandbox;
  late SessionFileStore store;

  setUpAll(() {
    Env().load(file: File('test/.env'));
    store = SessionFileStore();
  });

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('vania_session_fixation');
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

  Future<Map<String, dynamic>?> stored(String id) {
    store.invalidateCache();
    return store.retrieveSession(id);
  }

  test('an id the server never issued is not taken up', () async {
    final id = await _visit('chosen-by-an-attacker', (_) async {});
    expect(id, isNot('chosen-by-an-attacker'));
    expect(await stored('chosen-by-an-attacker'), isNull);
  });

  test('an existing session keeps its id', () async {
    await store.storeSession('issued', {'user': 1});
    expect(await _visit('issued', (_) async {}), 'issued');
  });

  test(
    'regenerating moves the session to a new id and ends the old one',
    () async {
      await store.storeSession('before-login', {'cart': 3});

      final id = await _visit('before-login', (sessions) async {
        await sessions.regenerateSession();
        await sessions.setSession('user', 7);
      });

      expect(id, isNot('before-login'));
      expect(await stored(id), containsPair('cart', 3));
      expect(await stored(id), containsPair('user', 7));
      expect(await stored('before-login'), isNull);
    },
  );

  test('changes made before regenerating go to the new id', () async {
    await store.storeSession('before-login', {'cart': 3});

    final id = await _visit('before-login', (sessions) async {
      await sessions.setSession('user', 7);
      await sessions.regenerateSession();
    });

    expect(await stored(id), containsPair('user', 7));
    expect(await stored('before-login'), isNull);
  });
}
