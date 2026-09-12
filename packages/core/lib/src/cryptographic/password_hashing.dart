import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'secure_compare.dart';

/// The framework's password-hashing algorithm, as pure functions.
///
/// ## Format
///
/// `vania1$<base64 salt>$<base64 digest>`
///
/// 32 random bytes of salt from `Random.secure()`, then 600,000 rounds of
/// HMAC-SHA512. The salt and pepper enter at round 0 and each round folds
/// the previous digest back in, so the work factor cannot be short-cut.
class PasswordHashing {
  const PasswordHashing._();

  static const String prefix = 'vania1';
  static const int saltBytes = 32;
  static const int iterations = 600000;

  static final Random _secureRandom = Random.secure();

  /// Hashes [password] with a fresh salt, peppered with [pepper].
  static String make(String password, String pepper) {
    final salt = generateSalt();
    return '$prefix\$$salt\$${derive(password, salt, pepper)}';
  }

  /// Verifies [password] against [hashed].
  ///
  /// Accepts both the current format and the legacy 4-character-salt
  /// layout, so passwords stored by older versions keep working. Never
  /// throws on malformed input — returns false.
  static bool verify(String password, String hashed, String pepper) {
    if (hashed.startsWith('$prefix\$')) {
      final parts = hashed.split('\$');
      if (parts.length != 3) return false;
      return secureEquals(derive(password, parts[1], pepper), parts[2]);
    }
    return _verifyLegacy(password, hashed, pepper);
  }

  /// True when [hashed] uses an older scheme and should be replaced the
  /// next time the plaintext password is available (i.e. at login).
  static bool needsRehash(String hashed) => !hashed.startsWith('$prefix\$');

  static bool _verifyLegacy(String password, String hashed, String pepper) {
    if (hashed.length < 4) return false;
    final salt = hashed.substring(0, 4);
    final hmac = Hmac(sha512, utf8.encode(pepper));
    final digest = base64.encode(
      hmac.convert(utf8.encode(salt + password)).bytes,
    );
    return secureEquals(salt + digest, hashed);
  }

  static String generateSalt() {
    final bytes = Uint8List(saltBytes);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return base64.encode(bytes);
  }

  static String derive(String password, String salt, String pepper) {
    final hmac = Hmac(sha512, utf8.encode(pepper));
    Digest digest = hmac.convert(utf8.encode(salt + password + pepper));
    for (var i = 0; i < iterations; i++) {
      digest = hmac.convert(digest.bytes);
    }
    return base64.encode(digest.bytes);
  }
}
