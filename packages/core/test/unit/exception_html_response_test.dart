import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/exception/base_http_exception.dart';
import 'package:vania/src/exception/forbidden_exception.dart';
import 'package:vania/src/exception/not_found_exception.dart';
import 'package:vania/src/exception/throttle_exception.dart';
import 'package:vania/src/http/response/response.dart';

/// Writes [response] once and returns what reaches the client.
Future<(int, String, HttpHeaders)> _send(Response response) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) => response.makeResponse(req.response));
  final client = HttpClient();
  final res = await (await client.get('127.0.0.1', server.port, '/')).close();
  final body = await res.transform(systemEncoding.decoder).join();
  client.close(force: true);
  await server.close(force: true);
  return (res.statusCode, body, res.headers);
}

void main() {
  test('an HTML error page carries the error status', () async {
    final notFound = NotFoundException(message: 'Gone');
    expect((await _send(notFound.response(true))).$1, 404);

    final forbidden = ForbiddenException(message: 'No');
    expect((await _send(forbidden.response(true))).$1, 403);
  });

  test('a map message shows its text, not the map', () async {
    final error = NotFoundException(message: {'message': 'Not found'});
    final (_, body, _) = await _send(error.response(true));
    expect(body, 'Not found');
  });

  test('the message is escaped in HTML', () async {
    const error = BaseHttpResponseException(
      message: '<script>x</script>',
      code: 400,
    );
    final (_, body, _) = await _send(error.response(true));
    expect(body, '&lt;script&gt;x&lt;&#47;script&gt;');
  });

  test('a throttled HTML request gets 429 and keeps Retry-After', () async {
    final error = ThrottleException(
      message: 'Slow down',
      code: 429,
      headers: {'Retry-After': '30'},
    );
    final (status, _, headers) = await _send(error.response(true));
    expect(status, 429);
    expect(headers.value('retry-after'), '30');
  });
}
