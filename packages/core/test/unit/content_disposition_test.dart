import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

/// The name a client saves the download under, read the way browsers do:
/// `filename*` (RFC 8187, UTF-8) when present, else `filename`.
String? _savedAs(String? disposition) {
  if (disposition == null) return null;
  final extended = RegExp(r"filename\*=UTF-8''([^;]+)").firstMatch(disposition);
  if (extended != null) return Uri.decodeComponent(extended.group(1)!);
  return RegExp(r'filename="([^"]*)"').firstMatch(disposition)?.group(1);
}

void main() {
  late Directory dir;
  late HttpServer server;
  late HttpClient client;
  final bytes = Uint8List.fromList([1, 2, 3]);

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('vania_disposition');
    final file = File('${dir.path}/file.pdf')..writeAsBytesSync(bytes);

    clearRouteCaches();
    Router.basePrefix(null);
    // The name comes in the query string, which arrives decoded.
    Router.get(
      '/path',
      (Request req) => Response.fromPath(
        file.path,
        download: true,
        fileName: req.query('name'),
      ),
    );
    Router.get(
      '/bytes',
      (Request req) => Response.download(req.query('name'), bytes),
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
    dir.deleteSync(recursive: true);
  });

  Future<(int, String?, int)> download(String route, String name) async {
    final rq = await client.get(
      '127.0.0.1',
      server.port,
      '/$route?name=${Uri.encodeQueryComponent(name)}',
    );
    rq.headers.set('accept', 'application/json');
    final res = await rq.close();
    final body = await res.fold<List<int>>([], (a, b) => a..addAll(b));
    return (
      res.statusCode,
      res.headers.value('content-disposition'),
      body.length,
    );
  }

  for (final route in ['path', 'bytes']) {
    group('Response.${route == 'path' ? 'fromPath' : 'download'}', () {
      test('a Persian file name is saved as it is', () async {
        final (status, disposition, length) = await download(
          route,
          'گزارش ماهانه.pdf',
        );
        expect(status, 200);
        expect(length, 3);
        expect(_savedAs(disposition), 'گزارش ماهانه.pdf');
        // Clients that only read `filename` still get a usable name.
        expect(disposition, contains('filename="'));
      });

      test('an ASCII name keeps its plain form', () async {
        final (status, disposition, _) = await download(route, 'report.pdf');
        expect(status, 200);
        expect(disposition, 'attachment; filename="report.pdf"');
      });

      test('quotes and line breaks cannot break out of the header', () async {
        final (status, disposition, _) = await download(
          route,
          'a"b\r\nSet-Cookie: x=1.pdf',
        );
        expect(status, 200);
        expect(disposition, isNot(contains('\n')));
        expect(
          RegExp(r'filename="([^"]*)"').firstMatch(disposition!),
          isNotNull,
        );
      });
    });
  }
}
