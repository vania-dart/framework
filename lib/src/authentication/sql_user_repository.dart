import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:vania/src/authentication/model/personal_access_token.dart';
import 'package:vania/src/authentication/user_repository.dart';

class SqlUserRepository implements UserRepository {
  final PersonalAccessTokens personalAccessToken;
  SqlUserRepository(this.personalAccessToken);

  /// Finds a user by their token if it has not been marked as deleted.
  ///
  /// This method queries the personal access tokens to find the first token
  /// that matches the provided [token] after hashing it and checks if it is not deleted.
  /// Returns a Map with user ID or `null` if no matching token is found.
  @override
  Future<Map<String, dynamic>?> findUserByToken(String token) async {
    return await personalAccessToken
        .query()
        .where('token', '=', md5.convert(utf8.encode(token)))
        .whereNull('deleted_at')
        .first(['id']);
  }

  /// Stores a new token into the database.
  ///
  /// Inserts a new record into the personal access tokens table with the provided
  /// details: [name], [userId], [token] (hashed), and [createdAt].

  @override
  Future<void> storeToken(
      {required String name,
      required String userId,
      required String token,
      required DateTime createdAt}) async {
    await personalAccessToken.query().insert({
      'name': name,
      'tokenable_id': userId,
      'token': md5.convert(utf8.encode(token)),
      'created_at': createdAt,
    });
  }

  /// Marks all tokens associated with a given [userId] as deleted at a specified or current time.
  ///
  /// This method updates all tokens for the specified [userId] by setting their `deleted_at`
  /// timestamp to [deletedAt] or the current time if not specified.

  @override
  Future<void> deleteTokenById(String userId, [DateTime? deletedAt]) async {
    await personalAccessToken
        .query()
        .where('tokenable_id', '=', userId)
        .update({'deleted_at': deletedAt ?? DateTime.now()});
  }

  /// Marks a specific token as deleted based on the token value.
  ///
  /// This method hashes the provided [token] and marks it as deleted at [deletedAt] or
  /// the current time if not specified.
  @override
  Future<void> deleteTokenByToken(String token, [DateTime? deletedAt]) async {
    await personalAccessToken
        .query()
        .where('token', '=', md5.convert(utf8.encode(token)))
        .update({'deleted_at': deletedAt ?? DateTime.now()});
  }
}
