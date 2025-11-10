import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class VaniaEncryption {
  static final List<int> _fixedNonce = List<int>.filled(12, 0);

  /// Encrypts the given [plainText] using the provided [passphrase].
  ///
  /// This method first encodes the [plainText] using Base64 and `UTF-8` encoding.
  /// Then, it creates a cryptographic key from the [passphrase] and uses the
  /// AES encryption algorithm to encrypt the text with a predefined initialization
  /// vector (IV). The result is an encrypted string returned in Base64 format.
  ///
  /// Parameters:
  /// - [plainText]: The text to be encrypted.
  /// - [passphrase]: The passphrase used to generate the encryption key.
  ///
  /// Returns:
  /// A Base64 encoded string representing the encrypted text.
  static Future<String> encryptString(
    String plainText,
    String passphrase,
  ) async {
    try {
      plainText = base64.encode(utf8.encode(plainText));

      final keyBytes = utf8.encode(
        passphrase.padRight(32, '0').substring(0, 32),
      );
      final secretKey = SecretKey(keyBytes);

      final plainBytes = utf8.encode(plainText);

      final aesGcm = AesGcm.with256bits();
      final secretBox = await aesGcm.encrypt(
        plainBytes,
        secretKey: secretKey,
        nonce: _fixedNonce,
      );

      final combined = <int>[];
      combined.addAll(secretBox.nonce);
      combined.addAll(secretBox.cipherText);
      combined.addAll(secretBox.mac.bytes);

      return base64.encode(combined);
    } catch (error) {
      return '';
    }
  }

  /// Decrypts the given [encryptedText] using the provided [passphrase].
  ///
  /// This method first creates a cryptographic key from the [passphrase].
  /// It then uses the AES encryption algorithm to decrypt the [encryptedText]
  /// with a predefined initialization vector (IV). The decrypted text is
  /// decoded from Base64 and `UTF-8` encoding to return the original plaintext.
  ///
  /// Parameters:
  /// - [encryptedText]: The text to be decrypted, in Base64 format.
  /// - [passphrase]: The passphrase used to generate the decryption key.
  ///
  /// Returns:
  /// The original plaintext if decryption is successful, or an empty
  /// string if decryption fails.
  static Future<String> decryptString(
    String encryptedText,
    String passphrase,
  ) async {
    try {
      final keyBytes = utf8.encode(
        passphrase.padRight(32, '0').substring(0, 32),
      );
      final secretKey = SecretKey(keyBytes);

      // Decode the base64 encrypted text
      final encryptedBytes = base64.decode(encryptedText);

      final nonce = encryptedBytes.sublist(0, 12);
      final mac = encryptedBytes.sublist(encryptedBytes.length - 16);
      final cipherText = encryptedBytes.sublist(12, encryptedBytes.length - 16);

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));

      final aesGcm = AesGcm.with256bits();
      final decryptedBytes = await aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      final decryptedText = utf8.decode(decryptedBytes);
      return utf8.decode(base64.decode(decryptedText));
    } catch (error) {
      return '';
    }
  }
}
