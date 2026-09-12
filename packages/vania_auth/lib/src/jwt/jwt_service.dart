import 'dart:convert';
import 'package:vania/vania.dart' show IoCContainer;

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtService {
  /// Builds an isolated instance.
  ///
  /// `JwtService()` returns the shared one; use this when a test or a piece
  /// of code needs its own.
  JwtService.createDefault();

  factory JwtService() =>
      IoCContainer().resolveOrDefault<JwtService>(JwtService.createDefault);

  String? _secretKey;
  String? _audience;
  String? _issuer;
  String? _jwtId;
  String? _subject;

  /// Default access-token lifetime, used when `createToken` is called
  /// without an explicit `expiresIn`.
  Duration accessTokenTtl = const Duration(hours: 1);

  /// Default refresh-token lifetime.
  ///
  /// Refresh tokens are recorded in the token store and rotated on every
  /// use by `Auth.createTokenByRefreshToken`, so a leaked one can be
  /// revoked rather than remaining valid for its full lifetime.
  Duration refreshTokenTtl = const Duration(days: 30);

  /// Whether to serialise the full user record into the access token.
  ///
  /// Defaults to false, and should stay that way: a JWT is signed, not
  /// encrypted, so anyone holding it can base64-decode the payload —
  /// including any column the model did not mark `hidden`. With this off
  /// the token carries the user id and the server loads the record
  /// through the configured `UserProvider`.
  bool includeUserClaim = false;

  final Map<String, String> _derivedKeyCache = {};

  JwtService configure({
    required String secretKey,
    String? audience,
    String? issuer,
    String? jwtId,
    String? subject,
    Duration? accessTokenTtl,
    Duration? refreshTokenTtl,
    bool? includeUserClaim,
    bool? deriveGuardKeys,
  }) {
    _secretKey = secretKey;
    _audience = audience;
    _issuer = issuer;
    _jwtId = jwtId;
    _subject = subject;
    if (accessTokenTtl != null) this.accessTokenTtl = accessTokenTtl;
    if (refreshTokenTtl != null) this.refreshTokenTtl = refreshTokenTtl;
    if (includeUserClaim != null) this.includeUserClaim = includeUserClaim;
    if (deriveGuardKeys != null) this.deriveGuardKeys = deriveGuardKeys;
    _derivedKeyCache.clear();
    return this;
  }

  /// Derives per-guard signing keys with HMAC rather than appending the
  /// guard name to the secret.
  ///
  /// Appending gives weak domain separation — the keys for guards `admin`
  /// and `admin2` are prefix-related — though HMAC-SHA256 is not broken
  /// by related keys, so the practical difference is small.
  ///
  /// Defaults to **false**: turning it on changes every signing key,
  /// which invalidates every token in circulation and logs out every
  /// user. Enable it on a new app, or during a planned maintenance
  /// window.
  bool deriveGuardKeys = false;

  /// Returns the signing key for [guard].
  String _getSecretKey([String guard = '']) {
    final secret = _secretKey;
    if (secret == null) {
      throw StateError(
        'JWT secret key not configured. Call JwtService().configure() first.',
      );
    }

    if (!deriveGuardKeys) return '$secret$guard';

    return _derivedKeyCache.putIfAbsent(guard, () {
      final mac = Hmac(sha256, utf8.encode(secret));
      return base64Url.encode(
        mac.convert(utf8.encode('vania.jwt.guard.$guard')).bytes,
      );
    });
  }

  Map<String, dynamic> createToken({
    required Map<String, dynamic> payload,
    required String guard,
    Duration? expiresIn,
    bool withRefreshToken = false,
  }) {
    final userId = payload['id'] != null
        ? {'id': payload['id']}
        : {'_id': payload['_id']};

    final jwt = JWT(
      {
        // Only carried when the app opts in — see [includeUserClaim].
        if (includeUserClaim) 'user': jsonEncode(payload),
        'type': 'access_token',
        ...userId,
      },
      audience: _audience == null ? null : Audience.one(_audience!),
      jwtId: _jwtId,
      issuer: _issuer,
      subject: _subject,
    );

    final expirationTime = expiresIn ?? accessTokenTtl;
    final accessToken = jwt.sign(
      SecretKey(_getSecretKey(guard)),
      expiresIn: expirationTime,
    );

    final result = <String, dynamic>{
      'access_token': accessToken,
      'expires_in': DateTime.now().add(expirationTime).toIso8601String(),
    };

    if (withRefreshToken) {
      final refreshJwt = JWT(
        {...userId, 'type': 'refresh_token'},
        audience: _audience == null ? null : Audience.one(_audience!),
        jwtId: _jwtId,
        issuer: _issuer,
        subject: _subject,
      );
      final refreshToken = refreshJwt.sign(
        SecretKey(_getSecretKey(guard)),
        expiresIn: refreshTokenTtl,
      );
      result['refresh_token'] = refreshToken;
      result['refresh_expires_in'] = DateTime.now()
          .add(refreshTokenTtl)
          .toIso8601String();
    }

    return result;
  }

  Map<String, dynamic> verify(String token, String guard, String expectedType) {
    try {
      final jwt = JWT.verify(
        token,
        SecretKey(_getSecretKey(guard)),
        audience: _audience == null ? null : Audience.one(_audience!),
        jwtId: _jwtId,
        issuer: _issuer,
        subject: _subject,
      );

      final payload = jwt.payload;
      if (payload is! Map<String, dynamic>) {
        throw JwtAuthException('Invalid JWT payload type');
      }

      if (payload['type'] != expectedType) {
        throw JwtAuthException('Invalid token type');
      }

      return payload;
    } on JWTExpiredException {
      rethrow;
    } on JWTException catch (e) {
      throw JwtAuthException('Invalid token: ${e.message}');
    }
  }

  Map<String, dynamic> refreshToken(
    String token,
    String guard, {
    Duration? expiresIn,
  }) {
    final payload = verify(token, guard, 'refresh_token');
    final userStr = payload['user'] as String?;
    final userPayload = userStr != null
        ? jsonDecode(userStr) as Map<String, dynamic>
        : <String, dynamic>{'id': payload['id'] ?? payload['_id']};
    return createToken(
      payload: userPayload,
      guard: guard,
      expiresIn: expiresIn,
      withRefreshToken: true,
    );
  }
}

class JwtAuthException implements Exception {
  final String message;
  JwtAuthException(this.message);

  @override
  String toString() => 'JwtAuthException: $message';
}
