import 'package:vania/src/authentication/token_handler/jwt/jwt_signer.dart';
import 'package:vania/src/authentication/token_handler/jwt/jwt_verifier.dart';

class JwtTokenHandler {
  final JwtSigner signer;
  final JwtVerifier verifier;

  JwtTokenHandler(this.signer, this.verifier);

  Map<String, dynamic> createToken(Map<String, dynamic> payload,
      {String guard = '', bool withRefreshToken = false}) {
    return signer.createToken(
      payload: payload,
      guard: guard,
      withRefreshToken: withRefreshToken,
    );
  }

  Map<String, dynamic> verifyToken(
      String token, String guard, String expectedType) {
    return verifier.verify(token, guard, expectedType);
  }

  Map<String, dynamic> refreshToken(String token, String guard) {
    final payload = verifyToken(token, guard, 'refresh_token');
    return createToken(payload, guard: guard, withRefreshToken: true);
  }
}
