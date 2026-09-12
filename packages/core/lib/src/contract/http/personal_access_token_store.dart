abstract interface class PersonalAccessTokenStore {
  Future<void> create({
    required String name,
    required dynamic tokenableId,
    required String tokenHash,
    required Duration? expiresIn,
  });

  Future<bool> exists(String tokenHash);

  Future<void> markUsed(String tokenHash);

  Future<void> revoke(String tokenHash);

  Future<void> revokeAll(dynamic userId);

  Future<void> revokeAllByName(String name);

  Future<bool> isRevoked(String tokenHash);

  Future<Map<String, dynamic>?> find(String tokenHash);
}
