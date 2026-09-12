import 'package:vania/vania.dart' show Logger, PasswordHashing;
import 'package:vania/vania.dart' show IoCContainer;

/// Password hashing for `vania_auth`.
///
/// A wrapper that resolves the pepper and delegates to core's
/// [PasswordHashing], which owns the algorithm and the hash format.
class PasswordHasher {
  /// Builds an isolated instance.
  ///
  /// `PasswordHasher()` returns the shared one; use this when a test or a piece
  /// of code needs its own.
  PasswordHasher.createDefault();

  factory PasswordHasher() => IoCContainer().resolveOrDefault<PasswordHasher>(
    PasswordHasher.createDefault,
  );

  /// The legacy default pepper.
  ///
  /// Public knowledge, so it provides no protection — but it cannot be
  /// swapped for `APP_KEY`, because every password already hashed under
  /// it would stop verifying and lock those users out. It stays, and the
  /// problem is made loud instead of silent. See [_getSecretKey].
  static const String _legacyDefaultKey = 'vania-default-key-change-me';

  static bool _warnedAboutDefaultKey = false;

  String? _hashKey;

  PasswordHasher setHashKey(String hashKey) {
    _hashKey = hashKey;
    return this;
  }

  /// To migrate off the default: call `setHashKey(env('APP_KEY'))` at
  /// boot, then re-hash each password on next successful login (verify
  /// with the old key, `make` with the new one).
  String _getSecretKey() {
    final key = _hashKey;
    if (key != null) return key;

    if (!_warnedAboutDefaultKey) {
      _warnedAboutDefaultKey = true;
      Logger.log(
        'PasswordHasher is using its built-in default key. This value is '
        'public, so the pepper adds no security. Call '
        'PasswordHasher().setHashKey(env("APP_KEY")) during boot.',
        type: Logger.WARNING,
      );
    }
    return _legacyDefaultKey;
  }

  String make(String password) =>
      PasswordHashing.make(password, _getSecretKey());

  bool verify(String plainPassword, String hashedPassword) =>
      PasswordHashing.verify(plainPassword, hashedPassword, _getSecretKey());

  /// True when [hashedPassword] uses an older scheme and should be
  /// replaced next time the plaintext is available.
  bool needsRehash(String hashedPassword) =>
      PasswordHashing.needsRehash(hashedPassword);

  static bool check(String plainPassword, String hashedPassword) =>
      PasswordHasher().verify(plainPassword, hashedPassword);

  static String makeStatic(String password) => PasswordHasher().make(password);
}
