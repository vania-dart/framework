import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:vania/vania.dart';

class Hash {
  static final Hash _singleton = Hash._internal();
  factory Hash() => _singleton;
  Hash._internal();

  String? _hashKey;

  Hash setHashKey(String hashKey) {
    _hashKey = hashKey;
    return this;
  }

  /// Generates a hashed password using PBKDF2.
  ///
  /// This method creates a unique salt and uses it along with the given
  /// password to generate a hash using the PBKDF2 algorithm. The resulting
  /// hashed password is a concatenation of the salt and the hash.
  ///
  /// Returns a string containing the salt followed by the hash.

  String make(String password) {
    String salt = _generateSalt();
    String hash = _hashPbkdf2(password, salt);
    String hashedPassword = salt + hash;
    return hashedPassword;
  }

  /// Verifies that the given [plainPassword] matches the given [hashedPassword].
  ///
  /// This method works by first extracting the salt from the given [hashedPassword]
  /// and then using the extracted salt and the given [plainPassword] to generate
  /// a hash using the PBKDF2 algorithm. The resulting hash is then compared to
  /// the given [hashedPassword] to check if it matches.
  ///
  /// Returns true if the given [plainPassword] matches the given [hashedPassword],
  /// false otherwise.
  bool verify(String plainPassword, String hashedPassword) {
    int saltLength = 4;
    String salt = hashedPassword.substring(0, saltLength);
    String hash = _hashPbkdf2(plainPassword, salt);
    String saltHash = salt + hash;
    return _hashEquals(saltHash, hashedPassword);
  }

  String _generateSalt() {
    const charset =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        4, (_) => charset.codeUnitAt(random.nextInt(charset.length))));
  }

  /// Hashes the given [password] using the given [salt] and the APP_KEY or
  /// the given hash key.
  ///
  /// The method works by first encoding the given [salt] and [password] into bytes.
  /// These bytes are then used to compute a SHA-512 HMAC using the bytes of
  /// the hash key or the APP_KEY if no hash key is given.
  ///
  /// The resulting HMAC bytes are then encoded using Base64 and returned as a
  /// string.
  String _hashPbkdf2(String password, String salt) {
    var bytes = utf8.encode(salt + password);
    var hmac = Hmac(sha512, utf8.encode(_hashKey ?? env('APP_KEY')));
    return base64.encode(hmac.convert(bytes).bytes);
  }

  /// Compares two strings in a timing-safe manner to prevent timing attacks.
  ///
  /// This method works by first checking if the lengths of the two strings
  /// are equal. If they are not, the method immediately returns false.
  ///
  /// If the lengths are equal, the method then compares the individual characters
  /// of the two strings. If any of the characters are not equal, the method
  /// immediately returns false.
  ///
  /// If all characters are equal, the method returns true.
  bool _hashEquals(String salt, String hashedPassword) {
    if (salt.length != hashedPassword.length) {
      return false;
    }
    var result = 0;
    for (int i = 0; i < salt.length; i++) {
      result |= salt.codeUnitAt(i) ^ hashedPassword.codeUnitAt(i);
    }
    return result == 0;
  }
}
