import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/route/set_static_path.dart';

/// One static request. Returns the status code, the response headers and
/// the number of body bytes the client actually received.
Future<({int status, HttpHeaders headers, int bodyBytes})> _get(
  String relPath, {
  Map<String, String> requestHeaders = const {},
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final handled = await setStaticPathAsync(req);
    if (!handled) {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    }
  });

  final client = HttpClient();
  final rq = await client.get(
    InternetAddress.loopbackIPv4.address,
    server.port,
    '/$relPath',
  );
  requestHeaders.forEach(rq.headers.set);
  final res = await rq.close();

  var bytes = 0;
  await for (final chunk in res) {
    bytes += chunk.length;
  }

  client.close(force: true);
  await server.close(force: true);
  return (status: res.statusCode, headers: res.headers, bodyBytes: bytes);
}

void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('vania_static_cache');
    // Redirect the asset root rather than moving the process working
    // directory, which is shared by every test file running concurrently.
    staticPublicRoot = '${sandbox.path}/public';
    File('${sandbox.path}/public/app.css')
      ..createSync(recursive: true)
      ..writeAsStringSync('body { color: red; }');
  });

  tearDown(() {
    staticPublicRoot = 'public';
    if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
  });

  test('a first request carries validators and a Cache-Control', () async {
    final res = await _get('app.css');

    expect(res.status, equals(HttpStatus.ok));
    expect(res.bodyBytes, greaterThan(0));
    expect(res.headers.value(HttpHeaders.etagHeader), isNotNull);
    expect(res.headers.value(HttpHeaders.lastModifiedHeader), isNotNull);
    expect(res.headers.value(HttpHeaders.cacheControlHeader), equals('no-cache'));
  });

  test('re-requesting with the returned ETag yields 304 and no body',
      () async {
    final first = await _get('app.css');
    final etag = first.headers.value(HttpHeaders.etagHeader)!;

    final second = await _get(
      'app.css',
      requestHeaders: {HttpHeaders.ifNoneMatchHeader: etag},
    );

    expect(second.status, equals(HttpStatus.notModified));
    expect(second.bodyBytes, isZero);
    expect(second.headers.value(HttpHeaders.etagHeader), equals(etag));
  });

  test('re-requesting with the returned Last-Modified yields 304', () async {
    // Guards the sub-second trap: HTTP dates have one-second granularity, so
    // a modified time that kept its milliseconds would always look newer than
    // the date we just handed out and nothing would ever revalidate.
    final first = await _get('app.css');
    final lastModified = first.headers.value(HttpHeaders.lastModifiedHeader)!;

    final second = await _get(
      'app.css',
      requestHeaders: {HttpHeaders.ifModifiedSinceHeader: lastModified},
    );

    expect(second.status, equals(HttpStatus.notModified));
    expect(second.bodyBytes, isZero);
  });

  test('If-None-Match: * is treated as a match', () async {
    final res = await _get(
      'app.css',
      requestHeaders: {HttpHeaders.ifNoneMatchHeader: '*'},
    );
    expect(res.status, equals(HttpStatus.notModified));
  });

  test('a stale ETag gets the full body back', () async {
    final res = await _get(
      'app.css',
      requestHeaders: {HttpHeaders.ifNoneMatchHeader: 'W/"deadbeef-1"'},
    );

    expect(res.status, equals(HttpStatus.ok));
    expect(res.bodyBytes, greaterThan(0));
  });

  test('editing the file invalidates the previous ETag', () async {
    final first = await _get('app.css');
    final etag = first.headers.value(HttpHeaders.etagHeader)!;

    // Push the modified time past the one-second resolution of the size and
    // mtime pair the tag is built from.
    final file = File('${sandbox.path}/public/app.css');
    file.writeAsStringSync('body { color: blue; } /* longer now */');
    file.setLastModifiedSync(
      DateTime.now().add(const Duration(seconds: 5)),
    );

    final second = await _get(
      'app.css',
      requestHeaders: {HttpHeaders.ifNoneMatchHeader: etag},
    );

    expect(second.status, equals(HttpStatus.ok));
    expect(second.headers.value(HttpHeaders.etagHeader), isNot(equals(etag)));
    expect(second.bodyBytes, greaterThan(0));
  });

  test('a malformed If-Modified-Since does not suppress the body', () async {
    final res = await _get(
      'app.css',
      requestHeaders: {HttpHeaders.ifModifiedSinceHeader: 'not-a-date'},
    );

    expect(res.status, equals(HttpStatus.ok));
    expect(res.bodyBytes, greaterThan(0));
  });

  test('a directory under public/ is not served as a file', () async {
    Directory('${sandbox.path}/public/assets').createSync(recursive: true);
    final res = await _get('assets');
    expect(res.status, equals(HttpStatus.notFound));
  });
}
