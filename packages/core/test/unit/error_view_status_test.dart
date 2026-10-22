import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/exception/internal_server_error.dart';
import 'package:vania/src/exception/page_expired_exception.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/session/session_file_store.dart';
import 'package:vania/src/http/session/session_gate.dart';
import 'package:vania/src/http/session/session_manager.dart';
import 'package:vania/src/ioc_container.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

/// An app's own error pages, `lib/resources/view/errors/*.html`, keep the
/// status of the error they show.
void main() {
  // The view engine reads templates relative to the working directory.
  final views = Directory('lib/resources');
  late Directory sessions;
  late HttpServer server;
  late HttpClient client;

  setUpAll(() async {
    expect(views.existsSync(), isFalse, reason: 'would delete real views');
    final errors = Directory('lib/resources/view/errors')
      ..createSync(recursive: true);
    for (final code in ['404', '419', '500']) {
      File('${errors.path}/$code.html').writeAsStringSync('page $code');
    }

    Env().load(file: File('test/.env'));
    resetSessionGate();
    IoCContainer().register<SessionManager>(
      SessionManager.new,
      singleton: true,
    );
    sessions = Directory.systemTemp.createTempSync('vania_error_views');
    SessionFileStore()
      ..sessionPath = sessions.path
      ..invalidateCache();

    clearRouteCaches();
    Router.basePrefix(null);
    Router.get('/broken', () => throw InternalServerError(message: 'x'));
    Router.get('/expired', () => throw PageExpiredException());
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
    views.deleteSync(recursive: true);
  });

  Future<(int, String)> page(String path) async {
    final rq = await client.get('127.0.0.1', server.port, path);
    rq.headers.set('accept', 'text/html');
    final res = await rq.close();
    return (res.statusCode, await res.transform(systemEncoding.decoder).join());
  }

  test('the 404 page is a 404', () async {
    expect(await page('/nowhere'), (404, 'page 404'));
  });

  test('the 500 page is a 500', () async {
    expect(await page('/broken'), (500, 'page 500'));
  });

  test('the 419 page is a 419', () async {
    expect(await page('/expired'), (419, 'page 419'));
  });
}
