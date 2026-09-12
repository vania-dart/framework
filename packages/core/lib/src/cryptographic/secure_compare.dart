import 'dart:convert';

/// Compares two secrets in time independent of where they first differ.
///
/// `==` on Dart strings short-circuits at the first mismatched code unit,
/// so the time it takes to reject a wrong value leaks how many leading
/// characters were correct. Given enough samples that is enough to
/// recover a token one character at a time.
///
/// Use this for anything an attacker supplies and we compare against a
/// secret: CSRF tokens, session identifiers, password hashes, signatures,
/// API keys.
///
/// The length difference is folded into the accumulator rather than
/// returned early, so comparing values of different lengths costs the
/// same as comparing equal-length ones.
bool secureEquals(String a, String b) {
  final bytesA = utf8.encode(a);
  final bytesB = utf8.encode(b);

  final length = bytesA.length > bytesB.length ? bytesA.length : bytesB.length;

  int result = bytesA.length ^ bytesB.length;
  for (int i = 0; i < length; i++) {
    final byteA = i < bytesA.length ? bytesA[i] : 0;
    final byteB = i < bytesB.length ? bytesB[i] : 0;
    result |= byteA ^ byteB;
  }

  return result == 0;
}
