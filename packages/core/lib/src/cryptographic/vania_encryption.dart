import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// AES-GCM 256 with a per-message random nonce.
///
/// The payload layout is `base64( nonce ‖ ciphertext ‖ mac )`, with a
/// fresh random 12-byte nonce per message — AES-GCM is only secure while
/// a (key, nonce) pair is never reused.
///
/// The key is derived from the passphrase with HKDF-SHA256 under a fixed
/// `info` label, so the whole passphrase contributes regardless of its
/// length and session encryption does not share key material with other
/// uses of the same secret. Derived keys are cached, since the session
/// store calls this on every request.
///
/// Changing the `info` label makes previously written payloads
/// undecryptable. That degrades safely here: [decryptString] returns an
/// empty string on any failure and the session layer reads that as "no
/// session".
class VaniaEncryption {
  static final AesGcm _aesGcm = AesGcm.with256bits();

  /// Domain-separation label. Changing it invalidates existing payloads.
  static const String _hkdfInfo = 'vania.session.v2';

  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Derived keys are cached: HKDF runs per encrypt/decrypt otherwise,
  /// and the session store calls this on every request.
  static final Map<String, SecretKey> _keyCache = {};

  static Future<SecretKey> _keyFrom(String passphrase) async {
    final cached = _keyCache[passphrase];
    if (cached != null) return cached;

    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      info: utf8.encode(_hkdfInfo),
      // A per-message salt would have to be stored alongside the payload
      // and would defeat the cache. HKDF is sound with an empty salt; the
      // per-message randomness lives in the GCM nonce, where it belongs.
      nonce: const <int>[],
    );

    _keyCache[passphrase] = derived;
    return derived;
  }

  /// Encrypts [plainText] with a passphrase-derived key and a fresh random
  /// nonce. Returns Base64(nonce ‖ ciphertext ‖ mac), or an empty string
  /// if encryption itself throws.
  static Future<String> encryptString(
    String plainText,
    String passphrase,
  ) async {
    try {
      final secretKey = await _keyFrom(passphrase);
      final nonce = _aesGcm.newNonce(); // per-message random 12 bytes
      final secretBox = await _aesGcm.encrypt(
        utf8.encode(plainText),
        secretKey: secretKey,
        nonce: nonce,
      );
      final combined = <int>[
        ...secretBox.nonce,
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ];
      return base64.encode(combined);
    } catch (_) {
      return '';
    }
  }

  /// Decrypts a payload produced by [encryptString]. Returns an empty
  /// string on any failure (bad key, corrupted data, wrong MAC).
  static Future<String> decryptString(
    String encryptedText,
    String passphrase,
  ) async {
    try {
      final secretKey = await _keyFrom(passphrase);
      final bytes = base64.decode(encryptedText);
      if (bytes.length < 12 + 16) return '';
      final nonce = bytes.sublist(0, 12);
      final mac = bytes.sublist(bytes.length - 16);
      final cipherText = bytes.sublist(12, bytes.length - 16);
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
      final decrypted = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
      return utf8.decode(decrypted);
    } catch (_) {
      return '';
    }
  }
}
