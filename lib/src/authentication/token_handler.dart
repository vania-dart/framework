abstract class TokenHandler {
  TokenHandler setPayload(Map<String, dynamic> payload);

  /// Creates a JSON Web Token (JWT) with optional parameters.
  Map<String, dynamic> createToken({
    String guard = '',
    Duration? expiresIn,
    bool withRefreshToken = false,
  });

  /// Refreshes a token using a refresh token.
  Map<String, dynamic> refreshToken(
    String token,
    String guard,
    Duration? expiresIn,
  );

  /// Verifies the validity of a token.
  Map<String, dynamic> verify(
    String token,
    String guard,
    String expectedType,
  );
}
