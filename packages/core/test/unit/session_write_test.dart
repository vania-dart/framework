import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/http/session/session_file_store.dart';
import 'package:vania/src/http/session/session_manager.dart';

/// Serves each request through [handlers], keyed by path, inside a request
/// scope with a started session — the way RequestHandler runs a request.
Future<HttpServer> _serve(
  Map<String, Future<void> Function(SessionManager s, HttpResponse res)>
  handlers,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) {
    runInRequestScope(req, () async {
      final sessions = SessionManager();
      await sessions.sessionStart(req, req.response);
      await handlers[req.uri.path]!(sessions, req.response);
    });
  });
  return server;
}

/// A browser holding [sessionId]: one the server issued, since it takes
/// up no other.
Future<void> _get(HttpServer server, String path, String sessionId) async {
  if (await SessionFileStore().retrieveSession(sessionId) == null) {
    await SessionFileStore().storeSession(sessionId, {});
  }
  final client = HttpClient();
  final rq = await client.get('127.0.0.1', server.port, path);
  rq.cookies.add(Cookie(SessionManager().sessionKey, sessionId));
  await (await rq.close()).drain<void>();
  client.close(force: true);
}

/// What is on disk for [sessionId], bypassing the in-memory cache.
Future<Map<String, dynamic>?> _stored(String sessionId) {
  SessionFileStore().invalidateCache();
  return SessionFileStore().retrieveSession(sessionId);
}

void main() {
  late Directory sandbox;
  late HttpServer server;

  setUp(() {
    Env().load(file: File('test/.env'));
    sandbox = Directory.systemTemp.createTempSync('vania_session_write');
    SessionFileStore()
      ..sessionPath = sandbox.path
      ..invalidateCache();
  });

  tearDown(() async {
    await server.close(force: true);
    SessionFileStore()
      ..sessionPath = 'storage/framework/sessions'
      ..invalidateCache();
    sandbox.deleteSync(recursive: true);
  });

  test('writes land on disk together, just before the response', () async {
    Map<String, dynamic>? midRequest;
    server = await _serve({
      '/set': (s, res) async {
        await s.setSession('a', 1);
        await s.setSession('b', 2);
        expect(await s.getSession<int>('a'), 1, reason: 'read your writes');
        midRequest = await _stored('sid-1');
        await Response.json({}).makeResponse(res);
      },
    });

    await _get(server, '/set', 'sid-1');

    expect(midRequest?['a'], isNull, reason: 'nothing written mid-request');
    expect(await _stored('sid-1'), containsPair('a', 1));
    expect(await _stored('sid-1'), containsPair('b', 2));
  });

  test('a concurrent request\'s writes to the same session survive', () async {
    final aHasWritten = Completer<void>();
    final releaseA = Completer<void>();
    server = await _serve({
      '/a': (s, res) async {
        await s.setSession('from_a', 1);
        aHasWritten.complete();
        await releaseA.future;
        await Response.json({}).makeResponse(res);
      },
      '/b': (s, res) async {
        await s.setSession('from_b', 2);
        await Response.json({}).makeResponse(res);
      },
    });

    final a = _get(server, '/a', 'sid-2');
    await aHasWritten.future;
    await _get(server, '/b', 'sid-2');
    releaseA.complete();
    await a;

    final stored = await _stored('sid-2');
    expect(stored, containsPair('from_a', 1));
    expect(stored, containsPair('from_b', 2));
  });

  test('deleting and destroying are saved too', () async {
    server = await _serve({
      '/fill': (s, res) async {
        await s.setSession('keep', 1);
        await s.setSession('drop', 2);
        await Response.json({}).makeResponse(res);
      },
      '/delete': (s, res) async {
        await s.deleteSession('drop');
        await Response.json({}).makeResponse(res);
      },
      '/destroy': (s, res) async {
        await s.destroyAllSessions();
        await s.setSession('fresh', 3);
        expect(await s.getSession<int?>('keep'), isNull);
        await Response.json({}).makeResponse(res);
      },
    });

    await _get(server, '/fill', 'sid-3');
    await _get(server, '/delete', 'sid-3');
    final afterDelete = await _stored('sid-3');
    expect(afterDelete, containsPair('keep', 1));
    expect(afterDelete!.containsKey('drop'), isFalse);

    await _get(server, '/destroy', 'sid-3');
    expect(await _stored('sid-3'), {'fresh': 3});
  });

  test('a response written without Response is still saved after', () async {
    server = await _serve({
      '/raw': (s, res) async {
        await s.setSession('raw', true);
        await currentRequestScope!.runBeforeResponse();
        await res.close();
      },
    });

    await _get(server, '/raw', 'sid-4');
    expect(await _stored('sid-4'), containsPair('raw', true));
  });
}
