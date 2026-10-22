import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/env.dart';
import 'package:vania/src/http/request/request_handler.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/middleware/throttle.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

void main() {
  late HttpServer server;
  late HttpClient client;

  setUpAll(() async {
    clearRouteCaches();
    Router.basePrefix(null);
    // Each test gets its own route, so its own counter.
    for (final path in ['/counted', '/reset', '/local', '/development']) {
      Router.get(
        path,
        () => Response.json({}),
      ).middleware([Throttle(maxAttempts: 3)]);
    }
    initializeRoutes();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(RequestHandler().handle);
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close(force: true);
    await server.close(force: true);
    clearRouteCaches();
  });

  setUp(() => Env().env['APP_ENV'] = 'production');
  tearDown(() => Env().env.remove('APP_ENV'));

  Future<HttpClientResponse> get(String path) async {
    final rq = await client.get('127.0.0.1', server.port, path);
    rq.headers.set('accept', 'application/json');
    final res = await rq.close();
    await res.drain<void>();
    return res;
  }

  test('Remaining counts the request it is sent with', () async {
    final remaining = <String?>[];
    final statuses = <int>[];
    for (var i = 0; i < 4; i++) {
      final res = await get('/counted');
      statuses.add(res.statusCode);
      remaining.add(res.headers.value('x-ratelimit-remaining'));
    }
    expect(statuses, [200, 200, 200, 429]);
    expect(remaining, ['2', '1', '0', '0']);
  });

  test(
    'Reset is when the window ends, the same on every request in it',
    () async {
      final first = (await get('/reset')).headers.value('x-ratelimit-reset');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final second = (await get('/reset')).headers.value('x-ratelimit-reset');
      expect(second, first);
      final resetAt = DateTime.parse(first!);
      final untilReset = resetAt.difference(DateTime.now());
      expect(untilReset, lessThanOrEqualTo(const Duration(minutes: 1)));
      expect(untilReset, greaterThan(const Duration(seconds: 55)));
    },
  );

  test('a local development app is not throttled', () async {
    // `local` is the documented development value of APP_ENV.
    Env().env['APP_ENV'] = 'local';
    for (var i = 0; i < 5; i++) {
      expect((await get('/local')).statusCode, 200);
    }
  });

  test('so is one that calls its environment development', () async {
    Env().env['APP_ENV'] = 'development';
    for (var i = 0; i < 5; i++) {
      expect((await get('/development')).statusCode, 200);
    }
  });
}
