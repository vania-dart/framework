import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/router.dart';

void main() {
  group('Correctness — cached RouteData is never mutated', () {
    setUp(() {
      clearRouteCaches();
    });

    test(
      'Request.params() does not mutate route.params on the cached RouteData',
      () async {
        Router.basePrefix(null);
        Router.get('/things/{id}', (int id) {}).whereInt('id');
        initializeRoutes();

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final done = Completer<RouteData>();
        server.listen((httpReq) async {
          final r = httpRouteHandler(httpReq);
          expect(r, isNotNull);
          expect(r!.params, isNotNull);
          expect(r.params!['id'], equals(7));

          final wrapped = Request().from(request: httpReq, route: r);
          for (var i = 0; i < 10; i++) {
            wrapped.params();
          }

          httpReq.response.statusCode = 200;
          await httpReq.response.close();
          if (!done.isCompleted) done.complete(r);
        });

        final client = HttpClient();
        final req = await client.get('127.0.0.1', server.port, '/things/7');
        final resp = await req.close();
        await resp.drain<void>();
        client.close(force: true);
        await done.future;
        await server.close(force: true);

        final server2 = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final second = Completer<RouteData>();
        server2.listen((httpReq) async {
          final r = httpRouteHandler(httpReq);
          expect(r, isNotNull);
          expect(
            r!.params!.containsKey('id'),
            isTrue,
            reason: 'route.params must not be mutated by the previous request',
          );
          httpReq.response.statusCode = 200;
          await httpReq.response.close();
          if (!second.isCompleted) second.complete(r);
        });
        final c2 = HttpClient();
        final r2 = await c2.get('127.0.0.1', server2.port, '/things/11');
        final resp2 = await r2.close();
        await resp2.drain<void>();
        c2.close(force: true);
        await second.future;
        await server2.close(force: true);
      },
    );
  });

  group('Correctness — currentRequestScope isolation', () {
    test('runInRequestScope binds a distinct RequestScope per zone; sibling '
        'zones see their own request', () async {
      final serverA = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverB = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      HttpRequest? seenA;
      HttpRequest? seenB;

      serverA.listen((r) async {
        await runInRequestScope(r, () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          seenA = currentRequestScope?.request;
          r.response.statusCode = 200;
          await r.response.close();
        });
      });
      serverB.listen((r) async {
        await runInRequestScope(r, () async {
          seenB = currentRequestScope?.request;
          r.response.statusCode = 200;
          await r.response.close();
        });
      });

      final c = HttpClient();
      final ra = c.get('127.0.0.1', serverA.port, '/a');
      final rb = c.get('127.0.0.1', serverB.port, '/b');
      final wa = await ra;
      final wb = await rb;
      await (await wa.close()).drain<void>();
      await (await wb.close()).drain<void>();
      c.close(force: true);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(seenA, isNotNull);
      expect(seenB, isNotNull);
      expect(seenA!.uri.path, equals('/a'));
      expect(seenB!.uri.path, equals('/b'));

      await serverA.close(force: true);
      await serverB.close(force: true);
    });

    test('currentRequestScope is null outside runInRequestScope', () async {
      expect(currentRequestScope, isNull);
    });
  });

  group('Correctness — RequestScope carries state', () {
    test(
      'sessionErrors / formData / flashSessions live on the scope',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final done = Completer<Map<String, dynamic>>();
        server.listen((r) async {
          await runInRequestScope(r, () async {
            final s = currentRequestScope!;
            s.sessionErrors['name'] = 'required';
            s.formData['email'] = 'x@y';
            s.flashSessions['msg'] = 'hi';
            r.response
              ..statusCode = 200
              ..write(
                jsonEncode({
                  'errors': s.sessionErrors,
                  'form': s.formData,
                  'flash': s.flashSessions,
                }),
              );
            await r.response.close();
            if (!done.isCompleted) {
              done.complete({
                'errors': s.sessionErrors,
                'form': s.formData,
                'flash': s.flashSessions,
              });
            }
          });
        });
        final c = HttpClient();
        final req = await c.get('127.0.0.1', server.port, '/');
        final resp = await req.close();
        await resp.drain<void>();
        c.close(force: true);
        final captured = await done.future;
        expect(captured['errors'], containsPair('name', 'required'));
        expect(captured['form'], containsPair('email', 'x@y'));
        expect(captured['flash'], containsPair('msg', 'hi'));
        await server.close(force: true);
      },
    );
  });
}
