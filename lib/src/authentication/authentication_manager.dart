abstract class AuthenticationManager {
  AuthenticationManager guard(String guard);
  AuthenticationManager login(Map<String, dynamic> user);
  bool get isAuthorized;
  Map<String, dynamic>? user();
  dynamic id();
  dynamic get(String field);
  Future<Map<String, dynamic>> createToken({
    Duration? expiresIn,
    bool withRefreshToken = false,
    bool customToken = false,
  });
  Future<Map<String, dynamic>> createTokenByRefreshToken(
    String token, {
    Duration? expiresIn,
    bool customToken = false,
  });
  Future<bool> deleteTokens();
  Future<bool> deleteCurrentToken();
  Future<bool> check(
    String token, {
    Map<String, dynamic>? user,
    bool isCustomToken = false,
  });
}
