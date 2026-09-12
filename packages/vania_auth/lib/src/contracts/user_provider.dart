abstract interface class UserProvider {
  Future<Map<String, dynamic>?> findById(dynamic id);

  Future<Map<String, dynamic>?> findByEmail(String email);

  Future<bool> validatePassword(
    Map<String, dynamic> user,
    String plainPassword,
  );

  Future<Map<String, dynamic>> create(Map<String, dynamic> data);

  String get idKey;
}
