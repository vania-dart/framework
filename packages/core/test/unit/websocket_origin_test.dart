import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/config/config.dart';
import 'package:vania/src/ioc_container.dart';
import 'package:vania/src/websocket/websocket_origin_policy.dart';

void main() {
  late HttpServer server;
  late String host;

  setUp(() async {
    IoCContainer().reset<WebSocketOriginPolicy>();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    host = '127.0.0.1:${server.port}';

    server.listen((req) async {
      final allowed = WebSocketOriginPolicy().isAllowed(req);
      req.response
        ..statusCode = 200
        ..write(allowed ? 'allow' : 'deny');
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    IoCContainer().reset<WebSocketOriginPolicy>();
  });

  Future<bool> decisionFor(String? origin) async {
    final client = HttpClient();
    final req = await client.get(
      InternetAddress.loopbackIPv4.address,
      server.port,
      '/ws',
    );
    if (origin != null) req.headers.set('origin', origin);
    final res = await req.close();
    final body = await res.transform(const Utf8Decoder()).join();
    client.close();
    return body == 'allow';
  }

  group('same-origin default (nothing configured)', () {
    test('a matching origin is allowed', () async {
      expect(await decisionFor('http://$host'), isTrue);
    });

    test('a foreign origin is rejected', () async {
      expect(await decisionFor('http://evil.example'), isFalse);
      expect(await decisionFor('https://attacker.test'), isFalse);
    });

    test('a look-alike host is rejected', () async {
      expect(await decisionFor('http://127.0.0.1.evil.test'), isFalse);
      expect(await decisionFor('http://evil-127.0.0.1'), isFalse);
    });

    test('a different port on the same host is rejected', () async {
      expect(await decisionFor('http://127.0.0.1:1'), isFalse);
    });

    test('a malformed origin is rejected rather than throwing', () async {
      expect(await decisionFor('://::'), isFalse);
      expect(await decisionFor('not a url'), isFalse);
    });
  });

  group('non-browser clients', () {
    test('a missing origin is allowed by default', () async {
      expect(await decisionFor(null), isTrue);
    });
  });

  group('explicit allow-list', () {
    tearDown(() {
      Config().setApplicationConfig = <String, dynamic>{};
      IoCContainer().reset<WebSocketOriginPolicy>();
    });

    void allow(List<String> origins) {
      Config().setApplicationConfig = <String, dynamic>{
        'websocket': {'allowed_origins': origins},
      };
      IoCContainer().reset<WebSocketOriginPolicy>();
    }

    test('an allow-listed foreign origin is accepted', () async {
      allow(['https://app.example']);
      expect(await decisionFor('https://app.example'), isTrue);
    });

    test('an origin outside the list is still rejected', () async {
      allow(['https://app.example']);
      expect(await decisionFor('https://evil.example'), isFalse);
    });

    test('the allow-list replaces the same-origin default', () async {
      allow(['https://app.example']);
      expect(
        await decisionFor('http://$host'),
        isFalse,
        reason: 'an explicit list replaces the default, not adds to it',
      );
    });

    test('a wildcard entry disables the check', () async {
      allow(['*']);
      expect(await decisionFor('https://anything.example'), isTrue);
    });

    test('matching is case-insensitive', () async {
      allow(['https://App.Example']);
      expect(await decisionFor('https://app.example'), isTrue);
    });
  });
}
