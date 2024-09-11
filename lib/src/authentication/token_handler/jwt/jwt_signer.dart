import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'jwt_config.dart';

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
