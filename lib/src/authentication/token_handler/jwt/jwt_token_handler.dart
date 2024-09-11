import 'package:vania/src/authentication/token_handler/jwt/jwt_signer.dart';
import 'package:vania/src/authentication/token_handler/jwt/jwt_verifier.dart';

/// Handles the generation and verification of JWT tokens.
///
/// This class uses the [JwtSigner] and [JwtVerifier] to generate and verify
/// JWT tokens. It provides the following methods:
///
/// - [createToken] generates a new JWT token with the given payload.
/// - [verifyToken] verifies the given JWT token and returns the payload.
/// - [refreshToken] verifies the given JWT token, and if valid, generates a
/// new JWT token with the same payload.
class JwtTokenHandler {
  /// The signer to use when generating a new JWT token.
  final JwtSigner signer;

  /// The verifier to use when verifying a JWT token.
  final JwtVerifier verifier;

  /// Constructor.
  ///
  /// Takes the [signer] and [verifier] to use.
  JwtTokenHandler(this.signer, this.verifier);

  /// Generates a new JWT token with the given payload.
  ///
  /// The [payload] is the payload of the token. The [guard] is the guard to use
  /// when generating the token. The [withRefreshToken] determines whether a
  /// refresh token should be generated.
  ///
  /// Returns a map containing the access token, the refresh token (if
  /// [withRefreshToken] is true), and the expiration date of the access token
  /// as a string in ISO 8601 format.
  Map<String, dynamic> createToken(Map<String, dynamic> payload,
      {String guard = '', bool withRefreshToken = false}) {
    return signer.createToken(
      payload: payload,
      guard: guard,
      withRefreshToken: withRefreshToken,
    );
  }

  /// Verifies the given JWT token and returns the payload.
  ///
  /// The [token] is the JWT token to verify. The [guard] is the guard to use
  /// when verifying the token. The [expectedType] is the expected type of the
  /// token.
  ///
  /// Returns the payload of the token.
  Map<String, dynamic> verifyToken(
      String token, String guard, String expectedType) {
    return verifier.verify(token, guard, expectedType);
  }

  /// Verifies the given JWT token, and if valid, generates a new JWT token
  /// with the same payload.
  ///
  /// The [token] is the JWT token to verify. The [guard] is the guard to use
  /// when verifying the token.
  ///
  /// Returns a map containing the access token, the refresh token, and the
  /// expiration date of the access token as a string in ISO 8601 format.
  Map<String, dynamic> refreshToken(String token, String guard) {
    final payload = verifyToken(token, guard, 'refresh_token');
    return createToken(payload, guard: guard, withRefreshToken: true);
  }
}
