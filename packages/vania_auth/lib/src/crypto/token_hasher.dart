import 'dart:convert';

import 'package:crypto/crypto.dart';

class TokenHasher {
  static String hash(String token) {
    return md5.convert(utf8.encode(token)).toString();
  }

  static String hashSha256(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }
}
