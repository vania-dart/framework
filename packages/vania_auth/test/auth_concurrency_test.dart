import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania_auth/vania_auth.dart';

/// `Auth` resolves its state from the request's `RequestScope`, so
/// concurrent requests each see their own user even though `Auth()` is a
/// singleton.
///
/// The `await`s here are interleaved deliberately: state shared between
/// requests only shows up when one request suspends and another logs in
/// before it resumes.

class _FakeUserProvider implements UserProvider {
  @override
  String get idKey => 'id';

  /// Yields to the event loop, so concurrent requests interleave while a
  /// user lookup is in flight.
  @override
  Future<Map<String, dynamic>?> findById(dynamic id) async {
    await Future<void>.delayed(Duration(milliseconds: Random().nextInt(5)));
    return {'id': id, 'email': 'user$id@example.com'};
  }

  @override
  Future<Map<String, dynamic>?> findByEmail(String email) async => null;

  @override
  Future<bool> validatePassword(Map<String, dynamic> u, String p) async => true;

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async => data;
}

/// Accepts every token hash it was given, keeping `Auth.check` on its
/// real code path without a database.
class _FakeTokenStore implements PersonalAccessTokenStore {
  final Set<String> _hashes = {};
  final Set<String> _revoked = {};

  @override
  Future<void> create({
    required String name,
    required dynamic tokenableId,
    required String tokenHash,
    required Duration? expiresIn,
  }) async {
    _hashes.add(tokenHash);
  }

  @override
  Future<bool> exists(String tokenHash) async {
    await Future<void>.delayed(Duration.zero);
    return _hashes.contains(tokenHash);
  }

  @override
  Future<bool> isRevoked(String tokenHash) async =>
      _revoked.contains(tokenHash);

  @override
  Future<void> markUsed(String tokenHash) async {}

  @override
  Future<void> revoke(String tokenHash) async => _revoked.add(tokenHash);

  @override
  Future<void> revokeAll(dynamic userId) async {}

  @override
  Future<void> revokeAllByName(String name) async {}

  @override
  Future<Map<String, dynamic>?> find(String tokenHash) async => null;
}

void main() {
  late _FakeTokenStore store;

  setUp(() {
    Auth().reset();
    store = _FakeTokenStore();
    JwtService().configure(secretKey: 'test-secret-key-at-least-32-chars!!');
    Auth()
      ..setTokenStore(store)
      ..setUserProvider(_FakeUserProvider());
  });

  /// Mints a real signed token for [userId] and registers its hash, so
  /// `Auth.check` exercises verify → store lookup → user load.
  Future<String> mintToken(int userId) async {
    return await runInScopeFor(userId, () async {
      final token = await Auth().login({'id': userId}).createToken();
      return token['access_token'] as String;
    });
  }

  test(
    '100 concurrent requests each resolve to their own user',
    () async {
      final tokens = <int, String>{};
      for (var i = 1; i <= 100; i++) {
        tokens[i] = await mintToken(i);
      }

      // Fire all 100 "requests" at once. Each asserts, after several
      // suspension points, that Auth still reports its own user.
      final results = await Future.wait(
        tokens.entries.map((entry) async {
          return await runInScopeFor(entry.key, () async {
            await Auth().check(entry.value);

            // Suspend a few times, giving other requests the chance to
            // run in between.
            for (var i = 0; i < 3; i++) {
              await Future<void>.delayed(
                Duration(milliseconds: Random().nextInt(3)),
              );
            }

            return _Observed(expected: entry.key, actual: Auth().id);
          });
        }),
      );

      final wrong = results.where((r) => r.expected != r.actual).toList();
      expect(
        wrong,
        isEmpty,
        reason:
            'Auth().id leaked across concurrent requests. Mismatches: '
            '${wrong.take(5).map((r) => "expected ${r.expected} got ${r.actual}").join(", ")}',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('a failing token does not disturb a concurrent valid one', () async {
    final goodToken = await mintToken(42);

    final outcomes = await Future.wait([
      // Valid token, with suspension points.
      runInScopeFor(42, () async {
        await Auth().check(goodToken);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return Auth().id;
      }),
      // Garbage token racing alongside it.
      runInScopeFor(99, () async {
        try {
          await Auth().check('not-a-real-token');
        } catch (_) {
          // expected
        }
        return Auth().id;
      }),
    ]);

    expect(outcomes[0], equals(42), reason: 'valid token lost its user');
    expect(outcomes[1], isNull, reason: 'failed auth must not inherit a user');
  });

  test('state does not survive past the end of a request scope', () async {
    await runInScopeFor(7, () async {
      Auth().login({'id': 7});
      expect(Auth().id, equals(7));
    });

    // Outside any scope we fall back to root state, which nothing has
    // logged into. A leak here means the per-request state escaped.
    expect(Auth().loggedIn, isFalse);
    expect(Auth().id, isNull);
  });
}

class _Observed {
  final int expected;
  final dynamic actual;
  _Observed({required this.expected, required this.actual});
}

/// Runs [body] inside a real [RequestScope], the same way core's
/// `RequestHandler` wraps every inbound request. Needs a genuine
/// `HttpRequest`, so we serve one from a loopback server per call.
Future<T> runInScopeFor<T>(int _, Future<T> Function() body) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final completer = Completer<T>();

  server.listen((httpReq) async {
    try {
      final result = await runInRequestScope(httpReq, body);
      completer.complete(result);
    } catch (e, s) {
      completer.completeError(e, s);
    } finally {
      httpReq.response.statusCode = 200;
      await httpReq.response.close();
    }
  });

  final client = HttpClient();
  final req = await client.get(
    InternetAddress.loopbackIPv4.address,
    server.port,
    '/',
  );
  final res = await req.close();
  await res.drain<void>();
  client.close();

  final value = await completer.future;
  await server.close(force: true);
  return value;
}
