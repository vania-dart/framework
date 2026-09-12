import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/response/response.dart';

/// Serves [response] once and returns the raw bytes plus the declared
/// Content-Length, so the wire form can be checked rather than the object.
Future<({List<int> body, int? contentLength, int status})> _send(
  Response Function() response,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    await response().makeResponse(req.response);
  });

  final client = HttpClient();
  final res = await (await client.get(
    InternetAddress.loopbackIPv4.address,
    server.port,
    '/',
  )).close();

  final body = <int>[];
  await for (final chunk in res) {
    body.addAll(chunk);
  }
  final len = res.headers.contentLength;
  final status = res.statusCode;
  client.close(force: true);
  await server.close(force: true);
  return (body: body, contentLength: len == -1 ? null : len, status: status);
}

/// Anything the encoder has to route through `toJson`.
class _Widget {
  _Widget(this.id);
  final int id;
  Map<String, dynamic> toJson() => {'widget': id};
}

void main() {
  group('JSON responses go out byte-identical to jsonEncode + utf8', () {
    final cases = <String, Object?>{
      'plain map': {'a': 1, 'b': 'x'},
      'nested structures': {
        'd': [
          1,
          2,
          {'k': null},
        ],
      },
      'non-ascii text': {'msg': 'سلام دنیا ✅ 🎉'},
      'characters needing escapes': {'s': 'line\nbreak\t"quote"\\slash'},
      'large integers': {'n': 9007199254740993},
      'doubles': {'a': 1.5, 'b': -0.0, 'c': 1e300},
      'empty containers': {'m': <String, dynamic>{}, 'l': <int>[]},
      'toJson objects': {'w': _Widget(7)},
      'top-level list': [1, 2, 3],
      'top-level string': 'hello',
    };

    cases.forEach((label, data) {
      test(label, () async {
        final res = await _send(() => Response.json(data));
        final expected = utf8.encode(jsonEncode(data));

        expect(res.status, equals(HttpStatus.ok));
        expect(res.body, equals(expected));
        // A wrong Content-Length would truncate or hang the client, and is
        // the failure mode a direct byte encoder could plausibly introduce.
        expect(res.contentLength, equals(expected.length));
      });
    });
  });

  test('an unencodable value still produces a response instead of hanging',
      () async {
    // DateTime has no toJson; both the old and new encoder throw on it, and
    // the handler is expected to answer rather than leave the socket open.
    final res = await _send(() => Response.json({'t': DateTime(2020)}));
    expect(res.status, equals(HttpStatus.ok));
    expect(utf8.decode(res.body), contains('jsonEncode Error'));
  });
}
