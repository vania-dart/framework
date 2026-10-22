import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/http/session/flash_messages.dart';
import 'package:vania/src/http/session/session_file_store.dart';
import 'package:vania/src/http/session/session_gate.dart';
import 'package:vania/src/http/session/session_manager.dart';
import 'package:vania/src/ioc_container.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

void main() {
  late Directory sandbox;
  late HttpServer server;
  late HttpClient client;
  final sessionCookie = SessionManager().sessionKey;

  setUpAll(() async {
    Env().load(file: File('test/.env'));
    Env().env['SESSION_ENABLED'] = 'true';
    // Registered by Application in an app.
    IoCContainer().register<SessionManager>(
      SessionManager.new,
      singleton: true,
    );
    resetSessionGate();
    sandbox = Directory.systemTemp.createTempSync('vania_flash');
    SessionFileStore()
      ..sessionPath = sandbox.path
      ..invalidateCache();

    clearRouteCaches();
    Router.basePrefix(null);
    Router.get('/save', () => Response.back('status', 'Saved'));
    Router.get('/flash-and-render', () {
      FlashMessages().flash('status', 'Shown now');
      // What rendering a view does once the page has used the values.
      FlashMessages().clear();
      return Response.json({});
    });
    Router.get('/submit', (Request req) async {
      await req.validate({'email': 'required'});
      return Response.json({'ok': true});
    });
    Router.get(
      '/page',
      () => Response.json({
        'messages': FlashMessages().messages,
        'errors': FlashMessages().errors,
        'old': FlashMessages().old,
      }),
    );
    initializeRoutes();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(RequestHandler().handle);
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.close(force: true);
    clearRouteCaches();
    Env().env.remove('SESSION_ENABLED');
    resetSessionGate();
    SessionFileStore()
      ..sessionPath = 'storage/framework/sessions'
      ..invalidateCache();
    sandbox.deleteSync(recursive: true);
  });

  /// One browser: the session cookie set by a response goes back with
  /// every later request.
  late String? session;
  setUp(() => session = null);

  Future<(int, Map<String, dynamic>?)> visit(String path) async {
    final rq = await client.get('127.0.0.1', server.port, path);
    rq.followRedirects = false;
    rq.headers
      ..set('accept', 'text/html,application/json')
      ..set('referer', 'http://127.0.0.1:${server.port}/page');
    if (session != null) rq.cookies.add(Cookie(sessionCookie, session!));
    final res = await rq.close();
    for (final c in res.cookies) {
      if (c.name == sessionCookie) session = c.value;
    }
    final body = await res.transform(utf8.decoder).join();
    return (
      res.statusCode,
      body.isEmpty ? null : jsonDecode(body) as Map<String, dynamic>,
    );
  }

  test('a flash message reaches the next request, once', () async {
    final (status, _) = await visit('/save');
    expect(status, 302);

    expect((await visit('/page')).$2!['messages'], {'status': 'Saved'});
    expect((await visit('/page')).$2!['messages'], isEmpty);
  });

  test('validation errors and old input survive the redirect back, '
      'passwords left out', () async {
    final (status, _) = await visit(
      '/submit?name=Ann&password=secret&password_confirmation=secret',
    );
    expect(status, 302);

    final page = (await visit('/page')).$2!;
    expect((page['errors'] as Map).keys, ['email']);
    expect(page['old'], {'name': 'Ann'});

    final again = (await visit('/page')).$2!;
    expect(again['errors'], isEmpty);
    expect(again['old'], isEmpty);
  });

  test('a message already shown by this request is not carried over', () async {
    await visit('/flash-and-render');
    expect((await visit('/page')).$2!['messages'], isEmpty);
  });
}
