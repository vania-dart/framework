import 'dart:convert';

import 'package:test/test.dart';
import 'package:vania_auth/vania_auth.dart';

/// Token claims, refresh-token rotation and revocation.
class _Store implements PersonalAccessTokenStore {
  final Map<String, Map<String, dynamic>> rows = {};
  final Set<String> revoked = {};

  @override
  Future<void> create({
    required String name,
    required dynamic tokenableId,
    required String tokenHash,
    required Duration? expiresIn,
  }) async {
    rows[tokenHash] = {'name': name, 'id': tokenableId};
  }

  @override
  Future<bool> exists(String tokenHash) async => rows.containsKey(tokenHash);

  @override
  Future<bool> isRevoked(String tokenHash) async => revoked.contains(tokenHash);

  @override
  Future<void> markUsed(String tokenHash) async {}

  @override
  Future<void> revoke(String tokenHash) async => revoked.add(tokenHash);

  @override
  Future<void> revokeAll(dynamic userId) async {
    rows.forEach((hash, row) {
      if (row['id'] == userId) revoked.add(hash);
    });
  }

  @override
  Future<void> revokeAllByName(String name) async {}

  @override
  Future<Map<String, dynamic>?> find(String tokenHash) async => rows[tokenHash];
}

class _Provider implements UserProvider {
  @override
  String get idKey => 'id';
  @override
  Future<Map<String, dynamic>?> findById(dynamic id) async => {
    'id': id,
    'email': 'u$id@example.com',
    'password': 'super-secret-hash',
  };
  @override
  Future<Map<String, dynamic>?> findByEmail(String e) async => null;
  @override
  Future<bool> validatePassword(Map<String, dynamic> u, String p) async => true;
  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> d) async => d;
}

/// Decodes a JWT payload without verifying — this is exactly what anyone
/// holding the token can do, which is the point of the claim tests.
Map<String, dynamic> payloadOf(String token) {
  var segment = token.split('.')[1];
  while (segment.length % 4 != 0) {
    segment += '=';
  }
  return jsonDecode(utf8.decode(base64Url.decode(segment)))
      as Map<String, dynamic>;
}

void main() {
  late _Store store;

  setUp(() {
    Auth().reset();
    store = _Store();
    JwtService().configure(
      secretKey: 'test-secret-key-at-least-32-chars!!',
      // Reset the tunables each test so ordering can't leak state.
      accessTokenTtl: const Duration(hours: 1),
      refreshTokenTtl: const Duration(days: 30),
      includeUserClaim: false,
      deriveGuardKeys: false,
    );
    Auth()
      ..setTokenStore(store)
      ..setUserProvider(_Provider());
  });

  group('token payload no longer carries the user record', () {
    test('the access token holds only the id, not the user row', () async {
      final token = await Auth().login({
        'id': 7,
        'email': 'a@b.c',
        'password': 'super-secret-hash',
      }).createToken();

      final claims = payloadOf(token['access_token'] as String);

      expect(claims['id'], equals(7));
      expect(
        claims.containsKey('user'),
        isFalse,
        reason: 'the token must not carry the user row',
      );
      expect(jsonEncode(claims), isNot(contains('super-secret-hash')));
    });

    test('apps can opt back in explicitly', () async {
      JwtService().configure(
        secretKey: 'test-secret-key-at-least-32-chars!!',
        includeUserClaim: true,
      );
      final token = await Auth().login({
        'id': 7,
        'role': 'admin',
      }).createToken();
      expect(payloadOf(token['access_token'] as String)['user'], isNotNull);
    });
  });

  group('refresh tokens are revocable', () {
    test('issuing a refresh token records it in the store', () async {
      await Auth().login({'id': 1}).createToken(withRefreshToken: true);

      expect(
        store.rows.values.where((r) => r['name'] == 'default:refresh').length,
        equals(1),
        reason: 'a stored hash is what makes revocation possible',
      );
    });

    test('refreshing rotates: the old token stops working', () async {
      final first = await Auth()
          .login({'id': 1})
          .createToken(withRefreshToken: true);
      final oldRefresh = first['refresh_token'] as String;

      await Auth().createTokenByRefreshToken(oldRefresh);

      // Replaying the rotated token must now fail.
      await expectLater(
        Auth().createTokenByRefreshToken(oldRefresh),
        throwsA(isA<JwtAuthException>()),
      );
    });

    test('reuse of a rotated token revokes the whole family', () async {
      final first = await Auth()
          .login({'id': 1})
          .createToken(withRefreshToken: true);
      final oldRefresh = first['refresh_token'] as String;

      final second = await Auth().createTokenByRefreshToken(oldRefresh);
      final newRefresh = second['refresh_token'] as String;

      // The rotated token is replayed.
      await expectLater(
        Auth().createTokenByRefreshToken(oldRefresh),
        throwsA(isA<JwtAuthException>()),
      );

      // The current token is invalidated too: once one of the pair is
      // known to have leaked, the whole family is suspect.
      await expectLater(
        Auth().createTokenByRefreshToken(newRefresh),
        throwsA(isA<JwtAuthException>()),
      );
    });

    test('a refresh issued before the upgrade is accepted once', () async {
      // No store row: a token minted before refresh tokens were recorded.
      final legacy =
          JwtService().createToken(
                payload: {'id': 1},
                guard: 'default',
                withRefreshToken: true,
              )['refresh_token']
              as String;

      await expectLater(
        Auth().createTokenByRefreshToken(legacy),
        completes,
        reason: 'sessions predating token storage must keep working',
      );
    });
  });

  group('configurable lifetimes', () {
    test('the access TTL is honoured', () async {
      JwtService().configure(
        secretKey: 'test-secret-key-at-least-32-chars!!',
        accessTokenTtl: const Duration(minutes: 5),
      );
      final token = await Auth().login({'id': 1}).createToken();
      final expiry = DateTime.parse(token['expires_in'] as String);

      expect(
        expiry.difference(DateTime.now()).inMinutes,
        lessThanOrEqualTo(5),
        reason: 'the configured TTL must be applied',
      );
    });
  });

  group('guard key derivation', () {
    test('is off by default, so tokens keep verifying across upgrades', () {
      expect(JwtService().deriveGuardKeys, isFalse);
    });

    test('when on, a token from one guard fails on another', () {
      JwtService().configure(
        secretKey: 'test-secret-key-at-least-32-chars!!',
        deriveGuardKeys: true,
      );
      final token =
          JwtService().createToken(
                payload: {'id': 1},
                guard: 'admin',
              )['access_token']
              as String;

      expect(
        () => JwtService().verify(token, 'user', 'access_token'),
        throwsA(isA<JwtAuthException>()),
      );
      expect(
        JwtService().verify(token, 'admin', 'access_token')['id'],
        equals(1),
      );
    });
  });
}
