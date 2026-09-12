import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/route/set_static_path.dart';

Future<HttpHeaders> _serve(String relPath, {required int size}) async {
  final cwd = Directory.current.path;
  final publicDir = Directory('$cwd/public');
  if (!await publicDir.exists()) await publicDir.create(recursive: true);
  final target = File('$cwd/public/$relPath');
  await target.create(recursive: true);
  await target.writeAsBytes(List<int>.filled(size, 65));
  addTearDown(() async {
    if (await target.exists()) await target.delete();
  });

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final headers = Completer<HttpHeaders>();

  server.listen((req) async {
    // Snapshot headers before the response is drained/closed.
    final snapshot = req.response.headers;
    final ok = await setStaticPathAsync(req);
    if (!ok) {
      await req.response.close();
    }
    if (!headers.isCompleted) headers.complete(snapshot);
  });

  final client = HttpClient();
  final resp = await (await client.get(
    '127.0.0.1',
    server.port,
    '/$relPath',
  )).close();
  await resp.drain<void>();
  client.close(force: true);
  await server.close(force: true);
  return headers.future;
}

void main() {
  group('setStaticPathAsync', () {
    test('when file exists, streams with matching Content-Length', () async {
      const size = 5 * 1024 * 1024; // 5 MiB
      final headers = await _serve('big.bin', size: size);
      expect(headers.contentLength, equals(size));
    });

    test(
      'when file not found, returns false and does not commit response',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final resultC = Completer<bool>();
        server.listen((req) async {
          final ok = await setStaticPathAsync(req);
          resultC.complete(ok);
          if (!ok) {
            req.response.statusCode = 404;
            await req.response.close();
          }
        });
        final client = HttpClient();
        final resp = await (await client.get(
          '127.0.0.1',
          server.port,
          '/does-not-exist-${DateTime.now().microsecondsSinceEpoch}.txt',
        )).close();
        await resp.drain<void>();
        final ok = await resultC.future;
        expect(ok, isFalse);
        client.close(force: true);
        await server.close(force: true);
      },
    );
  });

  group('files that must not be served', () {
    /// Requests [relPath] after creating it under `public/`, and reports
    /// whether the static handler took responsibility for the request.
    Future<bool> handled(String relPath) async {
      final cwd = Directory.current.path;
      final target = File('$cwd/public/$relPath');
      await target.create(recursive: true);
      await target.writeAsString('secret');
      addTearDown(() async {
        if (await target.exists()) await target.delete();
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final result = Completer<bool>();
      server.listen((req) async {
        final ok = await setStaticPathAsync(req);
        if (!ok) await req.response.close();
        if (!result.isCompleted) result.complete(ok);
      });

      final client = HttpClient();
      final rq = await client.get(
        InternetAddress.loopbackIPv4.address,
        server.port,
        '/$relPath',
      );
      final res = await rq.close();
      await res.drain<void>();
      client.close();
      final value = await result.future;
      await server.close(force: true);
      return value;
    }

    test('dotfiles are not served', () async {
      expect(await handled('.env'), isFalse);
    });

    test('files inside a dot directory are not served', () async {
      expect(await handled('.git/config'), isFalse);
    });

    test('ordinary files are still served', () async {
      expect(await handled('app.css'), isTrue);
    });

    test('file names are matched case-sensitively', () async {
      // Matching is case-sensitive, so a name with capitals resolves
      // the same way on any filesystem.
      expect(await handled('Logo.PNG'), isTrue);
    });
  });

  group('public/ gate', () {
    late Directory sandbox;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('vania_public_gate');
      // Redirect the asset root rather than moving the process working
      // directory, which is shared by every test file running concurrently.
      staticPublicRoot = '${sandbox.path}/public';
    });

    tearDown(() {
      staticPublicRoot = 'public';
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('with no public/ directory, a GET is not treated as static', () async {
      expect(Directory('${sandbox.path}/public').existsSync(), isFalse);
      expect(await _handledAt('index.html'), isFalse);
    });

    test('a public/ created after the absent answer was cached is picked up '
        'once the cache is reset', () async {
      // Prime the negative cache.
      expect(await _handledAt('late.css'), isFalse);

      File('${sandbox.path}/public/late.css')
        ..createSync(recursive: true)
        ..writeAsStringSync('body{}');

      resetStaticPathCache();
      expect(await _handledAt('late.css'), isTrue);
    });
  });
}

/// Issues a GET for [relPath] against a throwaway server and reports whether
/// the static handler took responsibility for it. Unlike `handled`, it
/// creates nothing — the caller controls what exists on disk.
Future<bool> _handledAt(String relPath) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final result = Completer<bool>();
  server.listen((req) async {
    final ok = await setStaticPathAsync(req);
    if (!ok) await req.response.close();
    if (!result.isCompleted) result.complete(ok);
  });

  final client = HttpClient();
  final res = await (await client.get(
    InternetAddress.loopbackIPv4.address,
    server.port,
    '/$relPath',
  )).close();
  await res.drain<void>();
  client.close(force: true);
  final value = await result.future;
  await server.close(force: true);
  return value;
}
