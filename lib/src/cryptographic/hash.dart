import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:vania/vania.dart';

class Hash {
  static final Hash _singleton = Hash._internal();
  factory Hash() => _singleton;
  Hash._internal();

  String? _hashKey;

  void setHashKey(String hashKey) {
    _hashKey = hashKey;
  }

  String passwordHash(String password) {
    String salt = _generateSalt();
    String hash = _hashPbkdf2(password, salt);
    String hashedPassword = salt + hash;
    return hashedPassword;
  }

  bool passwordVerify(String providedPassword, String storedHash) {
    int saltLength = 4;
    String salt = storedHash.substring(0, saltLength);
    String hash = _hashPbkdf2(providedPassword, salt);
    String recreatedStoredHash = salt + hash;
    return _hashEquals(recreatedStoredHash, storedHash);
  }

  String _generateSalt() {
    const charset =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        4, (_) => charset.codeUnitAt(random.nextInt(charset.length))));
  }

  String _hashPbkdf2(String password, String salt) {
    var bytes = utf8.encode(salt + password);
    var hmac = Hmac(sha512, utf8.encode(_hashKey ?? env('APP_KEY')));
    return base64.encode(hmac.convert(bytes).bytes);
  }

  bool _hashEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    var result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
