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

  Map<String, dynamic> createToken([
    String guard = '',
    Duration? expiresIn,
    bool withRefreshToken = false,
  ]) {
    final jwt = JWT({'id': _userPayload?['id'], 'type': 'access_token'});
    Map<String, dynamic> payload = {};
    Duration expirationTime = expiresIn ?? const Duration(hours: 1);

    String accessToken = jwt.sign(SecretKey('${env('APP_KEY')}$guard'),
        expiresIn: expirationTime);

    payload['access_token'] = accessToken;

    if (withRefreshToken) {
      final jwtRefresh =
          JWT({'id': _userPayload?['id'], 'type': 'refresh_token'});
      String refreshToken = jwtRefresh.sign(
          SecretKey('${env('APP_KEY')}$guard'),
          expiresIn: const Duration(days: 30));
      payload['refresh_token'] = refreshToken;
    }

    payload['expires_in'] =
        DateTime.now().add(expirationTime).toIso8601String();

    return payload;
  }

  Map<String, dynamic> refreshToken(
    String token, [
    String guard = '',
    Duration? expiresIn,
  ]) {
    final jwt = verify(token, guard, 'refresh_token');
    _userPayload = jwt;
    return createToken(guard, expiresIn, true);
  }

  Map<String, dynamic> verify(String token, String guard, String expectedType) {
    try {
      final jwt = JWT.verify(token, SecretKey('${env('APP_KEY')}$guard'));

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
