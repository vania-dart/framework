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

  /// Create new token for the given user.
  ///
  /// The token created is a JWT token that contains the user's ID, the
  /// guard's name, and the user's payload. The token is then signed with
  /// the secret key from the environment variable `JWT_SECRET_KEY`.
  ///
  /// If `withRefreshToken` is true, a refresh token is also created and
  /// returned in the `refresh_token` key of the map.
  ///
  /// The `expiresIn` parameter is the duration after which the token will
  /// expire. If not provided, the token will expire after 1 hour.
  ///
  /// Returns a map containing the following keys:
  ///
  /// * `access_token`: the JWT token
  /// * `refresh_token`: the refresh token if `withRefreshToken` is true
  /// * `expires_in`: the duration after which the token will expire in seconds
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

  /// Creates a new token from a given refresh token.
  ///
  /// This function verifies the given refresh token and if it is valid, creates a
  /// new token using the `createToken` method.
  ///
  /// The `expiresIn` parameter is the duration after which the new token will
  /// expire. If not provided, the token will expire after 1 hour.
  ///
  /// Returns a map containing the following keys:
  ///
  /// * `access_token`: the new JWT token
  /// * `refresh_token`: the new refresh token
  /// * `expires_in`: the duration after which the new token will expire in seconds
  Map<String, dynamic> refreshToken(
    String token, [
    String guard = '',
    Duration? expiresIn,
  ]) {
    final jwt = verify(token, guard, 'refresh_token');
    _userPayload = jwt;
    return createToken(guard, expiresIn, true);
  }

  /// Verifies a given JWT token and returns the payload if it is valid.
  ///
  /// The `expectedType` parameter is the expected type of the token. If the
  /// token is not of this type, an `Unauthenticated` exception will be thrown.
  ///
  /// The `guard` parameter is the guard to use when verifying the token. The
  /// secret key will be concatenated with the guard before verifying the
  /// token.
  ///
  /// Returns a map containing the payload of the token if it is valid.
  ///
  /// Throws an `Unauthenticated` exception if the token is invalid or expired.
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
