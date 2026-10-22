import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/http/session/session_file_store.dart';
import 'package:vania/src/http/session/session_manager.dart';

/// Serves one request with [handler] and returns the session id the
/// response hands the browser, or the one it came with when it hands none.
///
/// The session is started first, as for a browser asking for a page,
/// unless [started] is false: then [handler] meets the cookie as an API
/// request does.
Future<String> _visit(
  String sessionId,
  Future<void> Function(SessionManager sessions) handler, {
  bool started = true,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) {
    runInRequestScope(req, () async {
      final sessions = SessionManager();
      if (started) await sessions.sessionStart(req, req.response);
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
          .where((c) => c.name == SessionManager().sessionKey)
          .lastOrNull
          ?.value ??
      sessionId;
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

  test('nor is it taken up by a request that never started a session, '
      'such as a fetch to an API route', () async {
    final id = await _visit(
      'chosen-by-an-attacker',
      (sessions) => sessions.setSession('user', 7),
      started: false,
    );
    expect(id, isNot('chosen-by-an-attacker'));
    expect(await stored('chosen-by-an-attacker'), isNull);
    expect(await stored(id), containsPair('user', 7));
  });

  test('such a request still writes to a session the server issued', () async {
    await store.storeSession('issued', {'cart': 3});
    final id = await _visit(
      'issued',
      (sessions) => sessions.setSession('user', 7),
      started: false,
    );
    expect(id, 'issued');
    expect(await stored('issued'), {'cart': 3, 'user': 7});
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
