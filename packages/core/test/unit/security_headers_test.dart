import 'dart:io';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/route/middleware/security_headers.dart';
import 'package:vania/src/route/route_data.dart';

/// Response headers written by [SecurityHeaders], including the ones
/// Dart's HttpServer sets by default and this middleware overrides.
void main() {
  late HttpServer server;

  /// Runs [middleware] against a real request and returns the headers it
  /// wrote, plus the request headers the client sent.
  Future<Map<String, String>> headersFrom(
    SecurityHeaders middleware, {
    Map<String, String> requestHeaders = const {},
  }) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    server.listen((httpReq) async {
      final route = RouteData(
        method: 'get',
        path: '/',
        action: () {},
        preMiddleware: [],
        prefix: null,
      );
      final req = Request().from(request: httpReq, route: route);
      await middleware.handle(req);
      await httpReq.response.close();
    });

    final client = HttpClient();
    final req = await client.get(
      InternetAddress.loopbackIPv4.address,
      server.port,
      '/',
    );
    requestHeaders.forEach(req.headers.set);
    final res = await req.close();
    await res.drain<void>();

    final collected = <String, String>{};
    res.headers.forEach((name, values) {
      collected[name.toLowerCase()] = values.join(', ');
    });

    client.close();
    await server.close(force: true);
    return collected;
  }

  test('sets the baseline headers by default', () async {
    final headers = await headersFrom(SecurityHeaders());

    expect(headers['x-content-type-options'], equals('nosniff'));
    expect(
      headers['x-frame-options'],
      equals('DENY'),
      reason: 'tightens the SAMEORIGIN default',
    );
    expect(
      headers['referrer-policy'],
      equals('strict-origin-when-cross-origin'),
      reason: 'Dart sets no Referrer-Policy at all',
    );
  });

  test('drops the legacy X-XSS-Protection header Dart sets', () async {
    final headers = await headersFrom(SecurityHeaders());
    expect(headers.containsKey('x-xss-protection'), isFalse);
  });

  test('omits opt-in headers unless configured', () async {
    final headers = await headersFrom(SecurityHeaders());

    expect(headers.containsKey('content-security-policy'), isFalse);
    expect(headers.containsKey('permissions-policy'), isFalse);
  });

  test('emits configured opt-in headers', () async {
    final headers = await headersFrom(
      SecurityHeaders(
        contentSecurityPolicy: "default-src 'self'",
        permissionsPolicy: 'geolocation=()',
      ),
    );

    expect(headers['content-security-policy'], equals("default-src 'self'"));
    expect(headers['permissions-policy'], equals('geolocation=()'));
  });

  test('individual headers can be suppressed', () async {
    // Suppression removes the header rather than skipping the write:
    // some of these have a default that would otherwise remain.
    final headers = await headersFrom(
      SecurityHeaders(
        frameOptions: null,
        referrerPolicy: '',
        contentTypeOptions: null,
      ),
    );

    expect(headers.containsKey('x-frame-options'), isFalse);
    expect(headers.containsKey('referrer-policy'), isFalse);
    expect(headers.containsKey('x-content-type-options'), isFalse);
  });

  group('HSTS', () {
    test('is omitted over plain HTTP', () async {
      // Browsers ignore HSTS over HTTP; emitting it there is noise that
      // suggests protection the connection does not have.
      final headers = await headersFrom(SecurityHeaders());
      expect(headers.containsKey('strict-transport-security'), isFalse);
    });

    test('is emitted when a proxy reports HTTPS', () async {
      final headers = await headersFrom(
        SecurityHeaders(),
        requestHeaders: {'x-forwarded-proto': 'https'},
      );
      expect(
        headers['strict-transport-security'],
        equals('max-age=31536000; includeSubDomains'),
      );
    });

    test('honours an explicit override', () async {
      final headers = await headersFrom(
        SecurityHeaders(strictTransportSecurity: 'max-age=60'),
        requestHeaders: {'x-forwarded-proto': 'https'},
      );
      expect(headers['strict-transport-security'], equals('max-age=60'));
    });
  });
}
