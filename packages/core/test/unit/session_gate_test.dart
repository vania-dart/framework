import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania/src/http/session/session_file_store.dart';
import 'package:vania/src/http/session/session_gate.dart';
import 'package:vania/src/http/session/session_manager.dart';

/// Drives [count] cookie-less requests carrying a browser-style `Accept`
/// header through the same branch `RequestHandler._handleInScope` uses.
Future<void> _hammerWithHtmlAccept({int count = 5}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final accept = req.headers.value('accept') ?? '';
    // Mirrors RequestHandler: the Accept header alone must not be enough.
    final isHtml = accept.contains('html') && sessionsEnabled();
    if (isHtml) {
      await runInRequestScope(req, () async {
        await SessionManager().sessionStart(req, req.response);
      });
    }
    await req.response.close();
  });

  final client = HttpClient();
  for (var i = 0; i < count; i++) {
    final rq = await client.get(
      InternetAddress.loopbackIPv4.address,
      server.port,
      '/api/users',
    );
    rq.headers.set('accept', 'text/html,application/xhtml+xml');
    final res = await rq.close();
    await res.drain<void>();
  }
  client.close(force: true);
  await server.close(force: true);
}

void main() {
  late Directory sandbox;

  int sessionFileCount() {
    final dir = Directory(SessionFileStore().sessionPath);
    if (!dir.existsSync()) return 0;
    return dir.listSync().whereType<File>().length;
  }

  setUp(() {
    Env().load(file: File('test/.env'));
    sandbox = Directory.systemTemp.createTempSync('vania_session_gate');

    // Both roots are redirected into the sandbox, so nothing here depends on
    // the process working directory that other test files share.
    viewDirectoryForGate = '${sandbox.path}/lib/resources/view';
    SessionFileStore().sessionPath = '${sandbox.path}/storage/sessions';
    SessionFileStore().invalidateCache();
    resetSessionGate();
  });

  tearDown(() {
    viewDirectoryForGate = 'lib/resources/view';
    SessionFileStore()
      ..sessionPath = 'storage/framework/sessions'
      ..invalidateCache();
    resetSessionGate();
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  group('sessionsEnabled', () {
    test('is false for an app that ships no views', () {
      expect(sessionsEnabled(), isFalse);
    });

    test('is true once the app has a view directory', () {
      Directory('${sandbox.path}/lib/resources/view')
          .createSync(recursive: true);
      resetSessionGate();
      expect(sessionsEnabled(), isTrue);
    });

    test('is true when CSRF protection is on, views or not', () {
      // CSRF tokens are stored in the session, so the two cannot be
      // separated even for an app that renders nothing itself.
      Env().env['CSRF_PROTECTION_ENABLED'] = 'true';
      addTearDown(() => Env().env.remove('CSRF_PROTECTION_ENABLED'));
      resetSessionGate();
      expect(sessionsEnabled(), isTrue);
    });

    test('SESSION_ENABLED overrides the inference', () {
      Directory('${sandbox.path}/lib/resources/view')
          .createSync(recursive: true);
      Env().env['SESSION_ENABLED'] = 'false';
      addTearDown(() => Env().env.remove('SESSION_ENABLED'));
      resetSessionGate();
      expect(sessionsEnabled(), isFalse);
    });
  });

  group('API-only app', () {
    test('writes no session files however many html-Accept requests arrive',
        () async {
      await _hammerWithHtmlAccept();
      expect(sessionFileCount(), isZero);
    });

    test('creates no session storage directory at all', () async {
      await _hammerWithHtmlAccept();
      expect(Directory('${sandbox.path}/storage').existsSync(), isFalse);
    });
  });

  group('web app', () {
    setUp(() {
      Directory('${sandbox.path}/lib/resources/view')
          .createSync(recursive: true);
      resetSessionGate();
    });

    test('still gets a session per cookie-less visitor', () async {
      // Sessions are the point of a web app — the gate must not break them.
      await _hammerWithHtmlAccept(count: 3);
      expect(sessionFileCount(), equals(3));
    });
  });
}
