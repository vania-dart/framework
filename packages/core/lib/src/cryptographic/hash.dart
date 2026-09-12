import 'package:vania/env.dart' show env;
import 'package:vania/src/ioc_container.dart';

import 'password_hashing.dart';

/// Password hashing for application code.
class Hash {
  Hash.createDefault();

  factory Hash() => IoCContainer().resolveOrDefault<Hash>(Hash.createDefault);

  String? _hashKey;

  Hash setHashKey(String hashKey) {
    _hashKey = hashKey;
    return this;
  }

  /// The pepper mixed into every digest, on top of the per-password salt.
  ///
  /// Falls back to `APP_KEY`. A pepper only helps while it stays out of
  /// the database dump, so it has to be a real configured secret — an
  /// empty one is a configuration error, not something to paper over.
  String _pepper() {
    final key = _hashKey ?? env<String>('APP_KEY', '');
    if (key.isEmpty) {
      throw StateError(
        'Cannot hash passwords: neither Hash().setHashKey() nor APP_KEY '
        'is set. Set APP_KEY in your .env file.',
      );
    }
    return key;
  }

  /// Hashes [password] with a fresh random salt.
  String make(String password) => PasswordHashing.make(password, _pepper());

  /// Returns true when [plainPassword] matches [hashedPassword].
  ///
  /// Accepts hashes in the legacy 4-character-salt format too, so stored
  /// passwords keep working; pair with [needsRehash] to migrate them.
  bool verify(String plainPassword, String hashedPassword) =>
      PasswordHashing.verify(plainPassword, hashedPassword, _pepper());

  /// True when [hashedPassword] was produced by an older, weaker scheme
  /// and should be replaced next time the plaintext is available.
  ///
  /// ```dart
  /// if (Hash().verify(password, user.password)) {
  ///   if (Hash().needsRehash(user.password)) {
  ///     await user.update({'password': Hash().make(password)});
  ///   }
  /// }
  /// ```
  bool needsRehash(String hashedPassword) =>
      PasswordHashing.needsRehash(hashedPassword);
}
