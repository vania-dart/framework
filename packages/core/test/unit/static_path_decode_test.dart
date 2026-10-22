import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/set_static_path.dart';

/// Files in `public/` are named in text; their URLs arrive percent-encoded.
/// Decoding must never turn an escape into a way out of `public/`.
void main() {
  late Directory sandbox;
  late HttpServer server;

  setUpAll(() async {
    sandbox = Directory.systemTemp.createTempSync('vania_static_decode');
    final public = Directory('${sandbox.path}/public')..createSync();
    File('${public.path}/my file.css').writeAsStringSync('spaced');
    File('${public.path}/گزارش.txt').writeAsStringSync('persian');
    File('${public.path}/.env').writeAsStringSync('APP_KEY=secret');
    Directory('${public.path}/docs').createSync();
    File('${public.path}/docs/a.txt').writeAsStringSync('nested');
    File('${sandbox.path}/secret.txt').writeAsStringSync('outside public');
    staticPublicRoot = public.path;

    clearRouteCaches();
    initializeRoutes();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(RequestHandler().handle);
  });

  tearDownAll(() async {
    await server.close(force: true);
    clearRouteCaches();
    staticPublicRoot = 'public';
    sandbox.deleteSync(recursive: true);
  });

  /// Sends [rawPath] exactly as written.
  Future<(int, String)> get(String rawPath) async {
    final socket = await Socket.connect('127.0.0.1', server.port);
    socket.write(
      'GET $rawPath HTTP/1.1\r\nHost: x\r\nAccept: application/json\r\n'
      'Connection: close\r\n\r\n',
    );
    final raw = utf8.decode(await socket.expand((c) => c).toList());
    socket.destroy();
    return (
      int.parse(raw.split(' ')[1]),
      raw.substring(raw.indexOf('\r\n\r\n') + 4),
    );
  }

  test('a file whose name has a space is served', () async {
    expect(await get('/my%20file.css'), (200, 'spaced'));
  });

  test('a file with a Persian name is served', () async {
    expect(await get('/${Uri.encodeComponent('گزارش.txt')}'), (200, 'persian'));
  });

  test('a nested file is still served', () async {
    expect(await get('/docs/a.txt'), (200, 'nested'));
  });

  group('an escape never leads out of public/', () {
    for (final path in [
      '/%2E%2E/secret.txt',
      '/%2e%2e/secret.txt',
      '/docs/%2E%2E/%2E%2E/secret.txt',
      '/docs%2F..%2F..%2Fsecret.txt',
      '/..%5Csecret.txt',
      '/docs%5C..%5C..%5Csecret.txt',
    ]) {
      test(path, () async {
        final (status, body) = await get(path);
        expect(body, isNot(contains('outside public')));
        expect(status, isNot(200));
      });
    }
  });

  group('an escape never reaches a hidden file', () {
    for (final path in ['/%2Eenv', '/%2eenv', '/docs/%2E%2E/%2Eenv']) {
      test(path, () async {
        final (status, body) = await get(path);
        expect(body, isNot(contains('APP_KEY')));
        expect(status, isNot(200));
      });
    }
  });

  test('a NUL byte or a malformed escape is no file', () async {
    expect((await get('/my%20file.css%00.png')).$1, isNot(200));
    expect((await get('/%E0%A4%A.txt')).$1, isNot(200));
  });
}
