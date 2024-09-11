import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:vania/src/authentication/token_handler/jwt/jwt_config.dart';
import 'package:vania/src/exception/unauthenticated.dart';

/// Class to verify JWT token.
///
/// This class uses dart_jsonwebtoken library to verify the jwt token.
/// It will throw Unauthenticated exception if the token is invalid.
class JwtVerifier {
  /// The JWT config.
  final JwtConfig config;

  /// Constructor.
  ///
  /// [config] is the JWT config.
  JwtVerifier(this.config);

  /// Verify the JWT token.
  ///
  /// [token] is the JWT token to verify.
  /// [guard] is the guard used to generate the token.
  /// [expectedType] is the expected type of the token.
  ///
  /// Return the payload of the token.
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
