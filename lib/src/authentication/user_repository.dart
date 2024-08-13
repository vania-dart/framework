abstract class UserRepository {
  Future<void> storeToken(
      {required String name,
      required String userId,
      required String token,
      required DateTime createdAt});
  Future<Map<String, dynamic>?> findUserByToken(String token);
  Future<void> deleteTokenById(String userId, [DateTime? deletedAt]);
  Future<void> deleteTokenByToken(String token, [DateTime? deletedAt]);
}
