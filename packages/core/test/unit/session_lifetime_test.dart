import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/http/session/session_file_store.dart';
import 'package:vania/src/http/session/session_manager.dart';

/// A returning browser's session: it already has a CSRF token, so a visit
/// writes nothing on that account.
const _returning = {'user': 1, 'x_csrf_token': 'token', 'x_csrf_iv': 'iv'};

/// Visits once with [sessionId], the way RequestHandler runs a request,
/// and returns the cookies the response sets.
Future<List<Cookie>> _visit(String sessionId) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) {
    runInRequestScope(req, () async {
      await SessionManager().sessionStart(req, req.response);
      await Response.json({}).makeResponse(req.response);
    });
  });
  final client = HttpClient();
  final rq = await client.get('127.0.0.1', server.port, '/');
  rq.cookies
    ..add(Cookie(SessionManager().sessionKey, sessionId))
    ..add(Cookie('XSRF-TOKEN', 'cookie'));
  final res = await rq.close();
  await res.drain<void>();
  client.close(force: true);
  await server.close(force: true);
  return res.cookies;
}

void main() {
  late Directory sandbox;
  late SessionFileStore store;

  setUpAll(() {
    Env().load(file: File('test/.env'));
    // Read once, on first use, so it is set before anything reads it.
    Env().env['SESSION_LIFETIME'] = '4';
    store = SessionFileStore();
  });

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('vania_session_lifetime');
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

  Future<DateTime> expiryOf(String sessionId) async {
    store.invalidateCache();
    return (await store.retrieveSessionEntry(sessionId))!.expiresAt;
  }

  test('a session lasts SESSION_LIFETIME on the server too', () async {
    await store.storeSession('sid', {'user': 1});
    final left = (await expiryOf('sid')).difference(DateTime.now());
    expect(left, greaterThan(const Duration(seconds: 3)));
    expect(left, lessThanOrEqualTo(const Duration(seconds: 4)));
  });

  test('a session in use past half its lifetime is extended', () async {
    await store.storeSession('sid', _returning);
    final before = await expiryOf('sid');
    await Future<void>.delayed(const Duration(milliseconds: 2200));

    await _visit('sid');

    final after = await expiryOf('sid');
    expect(after.isAfter(before), isTrue);
    expect((await store.retrieveSession('sid'))?['user'], 1);
  });

  test('a fresh session is not written again for being read', () async {
    await store.storeSession('sid', _returning);
    final file = File(store.filePathFor('sid'));
    final written = file.lastModifiedSync();
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    await _visit('sid');

    expect(file.lastModifiedSync(), written);
  });

  test('the XSRF cookie lasts as long as the session', () async {
    Duration? xsrfLeft(List<Cookie> cookies) => cookies
        .where((c) => c.name == 'XSRF-TOKEN')
        .lastOrNull
        ?.expires
        ?.difference(DateTime.now());

    // A new session, with a token made for it.
    final fresh = xsrfLeft(await _visit('unknown'));
    expect(fresh, greaterThan(const Duration(seconds: 2)));
    expect(fresh, lessThanOrEqualTo(const Duration(seconds: 4)));

    // A returning browser gets it again on every page, as it does the
    // session cookie, so the two run out together.
    await store.storeSession('sid', _returning);
    final renewed = xsrfLeft(await _visit('sid'));
    expect(renewed, greaterThan(const Duration(seconds: 2)));
    expect(renewed, lessThanOrEqualTo(const Duration(seconds: 4)));
  });

  test('expired session files and stray temporary files are swept', () async {
    await store.storeSession('live', {'n': 1});
    await store.storeSession('dead', {'n': 2});
    final dead = File(store.filePathFor('dead'))
      ..setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));
    final stray = File('${store.filePathFor('live')}.tmp-abc')
      ..writeAsStringSync('half')
      ..setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));

    await store.sweepExpired();

    expect(dead.existsSync(), isFalse);
    expect(stray.existsSync(), isFalse);
    expect(File(store.filePathFor('live')).existsSync(), isTrue);
  });
}
