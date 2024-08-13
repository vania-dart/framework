import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:vania/src/authentication/token_handler.dart';
import 'package:vania/src/env_handler/env_interface.dart';
import 'package:vania/src/exception/unauthenticated.dart';

class JwtTokenHandler implements TokenHandler {
  final IEnv env;
  Map<String, dynamic>? _userPayload = {};

  JwtTokenHandler(this.env);
  @override
  JwtTokenHandler setPayload(Map<String, dynamic> payload) {
    _userPayload = payload;
    return this;
  }

  @override
  Map<String, dynamic> createToken({
    String guard = '',
    Duration? expiresIn,
    bool withRefreshToken = false,
  }) {
    String secretKey = env.get<String>(
      'JWT_SECRET_KEY',
    );
    if (secretKey.isEmpty) {
      secretKey = env.get<String>('APP_KEY');
    }
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
      audience: Audience.one(env.get<String>('JWT_AUDIENCE')),
      jwtId: env.get<String?>('JWT_ID'),
      issuer: env.get<String?>('JWT_ISSUER'),
      subject: env.get<String?>('JWT_SUBJECT'),
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

  @override
  Map<String, dynamic> refreshToken(
    String token, [
    String guard = '',
    Duration? expiresIn,
  ]) {
    final jwt = verify(token, guard, 'refresh_token');
    _userPayload = jwt;
    return createToken(
        guard: guard, expiresIn: expiresIn, withRefreshToken: true);
  }

  @override
  Map<String, dynamic> verify(String token, String guard, String expectedType) {
    String secretKey = env.get<String>('JWT_SECRET_KEY');
    if (secretKey.isEmpty) {
      secretKey = env.get<String>('APP_KEY');
    }
    try {
      final jwt = JWT.verify(
        token,
        SecretKey('$secretKey$guard'),
        audience: Audience.one(env.get<String>('JWT_AUDIENCE')),
        jwtId: env.get<String?>('JWT_ID'),
        issuer: env.get<String?>('JWT_ISSUER'),
        subject: env.get<String?>('JWT_SUBJECT'),
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
