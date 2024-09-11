import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'jwt_config.dart';

/// Signs a JSON Web Token (JWT) for the given payload.
///
/// The payload must contain either an 'id' or a '_id' key.
/// The token will contain the payload, the type of the token ('access_token' or 'refresh_token'),
/// and the user id.
///
/// The secret key will be the secret key of the JWT configuration, plus the given guard.
///
/// The token will be signed with the given secret key and the audience, jwt id, issuer, and subject
/// of the JWT configuration.
///
/// The token will be valid for the given duration.
///
/// If [withRefreshToken] is true, a refresh token will also be signed with the given secret key,
/// and the same payload, but with a duration of 30 days.
///
/// The function will return a map containing the access token and the refresh token (if [withRefreshToken]
/// is true), and the expiration date of the access token as a string in ISO 8601 format.
///
/// This class should be used to generate tokens for authentication.
class JwtSigner {
  final JwtConfig config;

  JwtSigner(this.config);

  Map<String, dynamic> createToken({
    required Map<String, dynamic> payload,
    String guard = '',
    Duration expiresIn = const Duration(hours: 1),
    bool withRefreshToken = false,
  }) {
    final userId = _extractUserId(payload);
    final secret = '${config.secretKey}$guard';

    final jwt = JWT(
      {
        'user': jsonEncode(payload),
        'type': 'access_token',
        ...userId,
      },
      audience: Audience.one(config.audience),
      jwtId: config.jwtId,
      issuer: config.issuer,
      subject: config.subject,
    );

    final accessToken = jwt.sign(SecretKey(secret), expiresIn: expiresIn);

    final response = {
      'access_token': accessToken,
      'expires_in': DateTime.now().add(expiresIn).toIso8601String(),
    };

    if (withRefreshToken) {
      final refreshJwt = JWT({...userId, 'type': 'refresh_token'});
      final refreshToken = refreshJwt.sign(SecretKey(secret),
          expiresIn: const Duration(days: 30));
      response['refresh_token'] = refreshToken;
    }

    return response;
  }

  Map<String, dynamic> _extractUserId(Map<String, dynamic> payload) {
    return payload.containsKey('id')
        ? {'id': payload['id']}
        : {'_id': payload['_id']};
  }
}
