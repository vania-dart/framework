import 'package:vania/vania.dart' show PersonalAccessTokenStore;

import '../crypto/token_hasher.dart';
import '../jwt/jwt_service.dart';

mixin HasApiTokens {
  PersonalAccessTokenStore? _tokenStore;

  void setTokenStore(PersonalAccessTokenStore store) {
    _tokenStore = store;
  }

  Map<String, dynamic> generateToken({
    required Map<String, dynamic> userPayload,
    required String guard,
    Duration? expiresIn,
    bool withRefreshToken = false,
    bool customToken = false,
  }) {
    final token = JwtService().createToken(
      payload: userPayload,
      guard: guard,
      expiresIn: expiresIn,
      withRefreshToken: withRefreshToken,
    );

    return token;
  }

  Future<void> storeToken({
    required String name,
    required dynamic tokenableId,
    required String accessToken,
    Duration? expiresIn,
  }) async {
    if (_tokenStore == null) return;
    await _tokenStore!.create(
      name: name,
      tokenableId: tokenableId,
      tokenHash: TokenHasher.hash(accessToken),
      expiresIn: expiresIn,
    );
  }

  Map<String, dynamic> verifyToken(
    String token,
    String guard,
    String expectedType,
  ) {
    return JwtService().verify(token, guard, expectedType);
  }
}
