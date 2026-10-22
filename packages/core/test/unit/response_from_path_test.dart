import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

void main() {
  late Directory dir;
  late File file;
  late HttpServer server;
  late HttpClient client;
  final content = List<int>.generate(1000, (i) => i % 251);

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('vania_from_path');
    file = File('${dir.path}/clip.mp4')..writeAsBytesSync(content);

    clearRouteCaches();
    Router.basePrefix(null);
    Router.get('/inline', () => Response.fromPath(file.path));
    Router.get(
      '/download',
      () => Response.fromPath(file.path, download: true, fileName: 'a.mp4'),
    );
    Router.get('/missing', () => Response.fromPath('${dir.path}/nope'));
    Router.query('/inline', () => Response.fromPath(file.path));
    initializeRoutes();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(RequestHandler().handle);
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.close(force: true);
    clearRouteCaches();
    dir.deleteSync(recursive: true);
  });

  Future<(HttpClientResponse, List<int>)> get(
    String path, [
    Map<String, String> headers = const {},
  ]) async {
    final rq = await client.get('127.0.0.1', server.port, path);
    headers.forEach(rq.headers.set);
    final res = await rq.close();
    final body = await res.fold<List<int>>([], (a, b) => a..addAll(b));
    return (res, body);
  }

  test('the whole file, advertising range support', () async {
    final (res, body) = await get('/inline');
    expect(res.statusCode, 200);
    expect(res.headers.contentLength, 1000);
    expect(res.headers.value('accept-ranges'), 'bytes');
    expect(res.headers.contentType?.mimeType, 'video/mp4');
    expect(body, content);
  });

  test('a byte range', () async {
    final (res, body) = await get('/inline', {'range': 'bytes=10-19'});
    expect(res.statusCode, 206);
    expect(res.headers.value('content-range'), 'bytes 10-19/1000');
    expect(body, content.sublist(10, 20));
  });

  test('an open-ended range and a suffix range', () async {
    final (open, openBody) = await get('/inline', {'range': 'bytes=990-'});
    expect(open.headers.value('content-range'), 'bytes 990-999/1000');
    expect(openBody, content.sublist(990));

    final (suffix, suffixBody) = await get('/inline', {'range': 'bytes=-5'});
    expect(suffix.headers.value('content-range'), 'bytes 995-999/1000');
    expect(suffixBody, content.sublist(995));
  });

  test('a range ending past the file is cut to the file', () async {
    final (res, body) = await get('/inline', {'range': 'bytes=998-5000'});
    expect(res.headers.value('content-range'), 'bytes 998-999/1000');
    expect(body, content.sublist(998));
  });

  test('a range starting past the file is a 416', () async {
    final (res, body) = await get('/inline', {'range': 'bytes=1000-1010'});
    expect(res.statusCode, 416);
    expect(res.headers.value('content-range'), 'bytes */1000');
    expect(body, isEmpty);
  });

  test('several ranges, or a malformed one, get the whole file', () async {
    for (final range in ['bytes=0-1,5-6', 'bytes=9-3', 'items=0-1']) {
      final (res, body) = await get('/inline', {'range': range});
      expect(res.statusCode, 200, reason: range);
      expect(body, content, reason: range);
    }
  });

  test('If-Range for another version gets the whole file', () async {
    final (res, body) = await get('/inline', {
      'range': 'bytes=0-9',
      'if-range': 'Thu, 01 Jan 1970 00:00:00 GMT',
    });
    expect(res.statusCode, 200);
    expect(body, content);

    final current = (await get('/inline')).$1.headers.value('last-modified')!;
    final (match, _) = await get('/inline', {
      'range': 'bytes=0-9',
      'if-range': current,
    });
    expect(match.statusCode, 206);
  });

  test('a download is named for saving', () async {
    final (res, body) = await get('/download');
    expect(
      res.headers.value('content-disposition'),
      'attachment; filename="a.mp4"',
    );
    expect(body, content);
  });

  test('a QUERY takes a range as a GET does (RFC 10008 §2.8)', () async {
    final rq = await client.open('QUERY', '127.0.0.1', server.port, '/inline');
    rq.headers
      ..set('content-type', 'application/json')
      ..set('range', 'bytes=0-9');
    rq.write('{}');
    final res = await rq.close();
    final body = await res.fold<List<int>>([], (a, b) => a..addAll(b));
    expect(res.statusCode, 206);
    expect(body, content.sublist(0, 10));
  });

  test('a missing file is a 404', () async {
    final (res, _) = await get('/missing');
    expect(res.statusCode, 404);
  });
}
