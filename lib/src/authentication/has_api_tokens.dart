import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/vania.dart';

class HasApiTokens {
  static final HasApiTokens _singleton = HasApiTokens._internal();
  factory HasApiTokens() => _singleton;
  HasApiTokens._internal();

  Map<String, dynamic>? _userPayload = {};

  HasApiTokens setPayload(Map<String, dynamic> payload) {
    _userPayload = payload;
    return this;
  }

  /// Create new token
  Map<String, dynamic> createToken([
    String guard = '',
    Duration? expiresIn,
    bool withRefreshToken = false,
  ]) {
    String secretKey = env('JWT_SECRET_KEY') ?? env<String>('APP_KEY');
    Map<String, dynamic> userId = {'id': _userPayload?['id']};
    if (_userPayload?['id'] == null) {
      userId = {'_id': _userPayload?['_id']};
    }

    final jwt = JWT(
      {
        'user': jsonEncode(_userPayload),
        'type': 'access_token',
        ...userId,
      },
      audience: env('JWT_AUDIENCE') == null
          ? null
          : Audience.one(env<String>('JWT_AUDIENCE')),
      jwtId: env<String?>('JWT_ID'),
      issuer: env<String?>('JWT_ISSUER'),
      subject: env<String?>('JWT_SUBJECT'),
    );
    Map<String, dynamic> payload = {};
    Duration expirationTime = expiresIn ?? const Duration(hours: 1);

    String accessToken =
        jwt.sign(SecretKey('$secretKey$guard'), expiresIn: expirationTime);

    payload['access_token'] = accessToken;

    if (withRefreshToken) {
      final jwtRefresh = JWT({
        ...userId,
        'type': 'refresh_token',
      });
      String refreshToken = jwtRefresh.sign(SecretKey('$secretKey$guard'),
          expiresIn: const Duration(days: 30));
      payload['refresh_token'] = refreshToken;
    }

    payload['expires_in'] =
        DateTime.now().add(expirationTime).toIso8601String();

    return payload;
  }

  /// Create new refresh token
  Map<String, dynamic> refreshToken(
    String token, [
    String guard = '',
    Duration? expiresIn,
  ]) {
    final jwt = verify(token, guard, 'refresh_token');
    _userPayload = jwt;
    return createToken(guard, expiresIn, true);
  }

// Verify token
  Map<String, dynamic> verify(String token, String guard, String expectedType) {
    String secretKey = env('JWT_SECRET_KEY') ?? env<String>('APP_KEY');
    try {
      final jwt = JWT.verify(
        token,
        SecretKey('$secretKey$guard'),
        audience: env('JWT_AUDIENCE') == null
            ? null
            : Audience.one(env<String>('JWT_AUDIENCE')),
        jwtId: env<String?>('JWT_ID'),
        issuer: env<String?>('JWT_ISSUER'),
        subject: env<String?>('JWT_SUBJECT'),
      );

      if (jwt.payload['type'] != expectedType) {
        throw Unauthenticated(message: 'Invalid token');
      }

      return jwt.payload;
    } on JWTExpiredException {
      rethrow;
    } on JWTException {
      throw Unauthenticated(message: 'Invalid token');
    }
  }
}
