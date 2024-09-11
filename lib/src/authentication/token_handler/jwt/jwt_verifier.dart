import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'jwt_config.dart';
import 'package:vania/src/exception/unauthenticated.dart';

class JwtVerifier {
  final JwtConfig config;

  JwtVerifier(this.config);

  Map<String, dynamic> verify(String token, String guard, String expectedType) {
    final secret = '${config.secretKey}$guard';

    try {
      final jwt = JWT.verify(
        token,
        SecretKey(secret),
        audience: Audience.one(config.audience),
        jwtId: config.jwtId,
        issuer: config.issuer,
        subject: config.subject,
      );

      if (jwt.payload['type'] != expectedType) {
        throw Unauthenticated(message: 'Invalid token type');
      }

      return jwt.payload;
    } on JWTExpiredException {
      rethrow;
    } on JWTException {
      throw Unauthenticated(message: 'Invalid token');
    }
  }
}
