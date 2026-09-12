import '../contracts/user_provider.dart';
import '../crypto/hash.dart';

class ModelUserProvider implements UserProvider {
  final dynamic model;
  final String idColumn;
  final String emailColumn;
  final String passwordColumn;
  final String? deletedAtColumn;
  final PasswordHasher hasher;

  ModelUserProvider({
    required this.model,
    this.idColumn = 'id',
    this.emailColumn = 'email',
    this.passwordColumn = 'password',
    this.deletedAtColumn = 'deleted_at',
    PasswordHasher? hasher,
  }) : hasher = hasher ?? PasswordHasher();

  @override
  String get idKey => idColumn;

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final created = await model.create(Map<String, dynamic>.from(data));
    return Map<String, dynamic>.from(created);
  }

  @override
  Future<Map<String, dynamic>?> findByEmail(String email) {
    return _firstBy(emailColumn, email);
  }

  @override
  Future<Map<String, dynamic>?> findById(dynamic id) {
    return _firstBy(idColumn, id);
  }

  @override
  Future<bool> validatePassword(
    Map<String, dynamic> user,
    String plainPassword,
  ) async {
    final hashedPassword = user[passwordColumn];
    if (hashedPassword is! String) return false;
    return hasher.verify(plainPassword, hashedPassword);
  }

  Future<Map<String, dynamic>?> _firstBy(String column, dynamic value) async {
    final query = model.query.where(column, '=', value);
    final activeQuery = deletedAtColumn == null
        ? query
        : query.whereNull(deletedAtColumn!);
    final result = await activeQuery.first();
    if (result == null) return null;
    return Map<String, dynamic>.from(result);
  }
}
