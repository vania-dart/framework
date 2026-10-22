import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/http/session/session_file_store.dart';
import 'package:vania/src/http/session/session_gate.dart';
import 'package:vania/src/http/session/session_manager.dart';
import 'package:vania/src/ioc_container.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

/// Once REQUEST_TIMEOUT has answered a request, the handler that is still
/// running cannot be stopped — but nothing it does later reaches the
/// client or the session.
void main() {
  late Directory sessions;
  late HttpServer server;
  late HttpClient client;

  setUpAll(() async {
    Env().load(file: File('test/.env'));
    // Read once, on first use, so they are set before any request.
    Env().env['REQUEST_TIMEOUT'] = '1';
    Env().env['SESSION_ENABLED'] = 'true';
    resetSessionGate();
    IoCContainer().register<SessionManager>(
      SessionManager.new,
      singleton: true,
    );
    sessions = Directory.systemTemp.createTempSync('vania_timeout_abandon');
    SessionFileStore()
      ..sessionPath = sessions.path
      ..invalidateCache();

    clearRouteCaches();
    Router.basePrefix(null);
    Router.get('/slow', () async {
      await IoCContainer().resolve<SessionManager>().setSession('late', true);
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      return Response.json({'late': true});
    });
    initializeRoutes();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(RequestHandler().handle);
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.close(force: true);
    clearRouteCaches();
    resetSessionGate();
    SessionFileStore()
      ..sessionPath = 'storage/framework/sessions'
      ..invalidateCache();
    sessions.deleteSync(recursive: true);
  });

  test(
    'the handler\'s late response and session changes are dropped',
    () async {
      // An existing session, so it is the one the request works with.
      await SessionFileStore().storeSession('sid', {'user': 1});

      final rq = await client.get('127.0.0.1', server.port, '/slow');
      rq.headers.set('accept', 'text/html');
      rq.cookies.add(Cookie(SessionManager().sessionKey, 'sid'));
      final res = await rq.close();
      await res.drain<void>();
      expect(res.statusCode, 503);

      // Let the handler finish what it was doing.
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      SessionFileStore().invalidateCache();
      final stored = await SessionFileStore().retrieveSession('sid');
      expect(stored?['user'], 1);
      expect(stored?['late'], isNull, reason: 'saved after the 503 went out');
    },
  );
}
