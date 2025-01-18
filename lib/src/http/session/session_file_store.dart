// ignore_for_file: unintended_html_in_doc_comment, file_names

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:vania/vania.dart';

import '../../cryptographic/vania_encryption.dart';

class SessionFileStore {
  static final SessionFileStore _singleton = SessionFileStore._internal();
  factory SessionFileStore() => _singleton;
  SessionFileStore._internal();

  final String _secretKey = env('APP_KEY');

  final String sessionPath = 'storage/framework/sessions';

  /// Stores a session in the file system. The session is stored in the sessionPath directory,
  /// and the filename is the hash of the given sessionId. The session data is encrypted
  /// using the APP_KEY from the environment.
  ///
  /// The session data is stored in the file with the following format:
  /// {
  ///   "data": <the session data>,
  ///   "expiration": <the expiration time in milliseconds>
  /// }
  ///
  /// The expiration time is calculated from the current UTC time plus the given duration.
  /// The default duration is 1 hour.
  ///
  /// The method is asynchronous and returns a Future<void>.
  Future<void> storeSession(String sessionId, Map<String, dynamic> data,
      {Duration duration = const Duration(hours: 1)}) async {
    sessionId = _makeHash(sessionId).toString();
    final file = File('$sessionPath/$sessionId');

    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }

    int expiration =
        DateTime.now().toUtc().millisecondsSinceEpoch + duration.inMilliseconds;
    await file.writeAsString(VaniaEncryption.encryptString(
        json.encode({"data": data, "expiration": expiration}), _secretKey));
  }

  /// Retrieves a session from the file system. The session is retrieved from the sessionPath directory,
  /// and the filename is the hash of the given sessionId. The session data is decrypted
  /// using the APP_KEY from the environment.
  ///
  /// The method is synchronous and returns a Map<String, dynamic> containing the session data.
  /// If the session has expired, the method deletes the file and returns null.
  Future<Map<String, dynamic>?> retrieveSession(String sessionId) async {
    sessionId = _makeHash(sessionId).toString();
    final file = File('$sessionPath/$sessionId');

    if (!file.existsSync()) {
      return null;
    }

    Map<String, dynamic> data = json.decode(
        VaniaEncryption.decryptString(await file.readAsString(), _secretKey));
    int expiration = data['expiration'].toString().toInt() ?? 0;
    if (!DateTime.now()
        .toUtc()
        .isBefore(DateTime.fromMillisecondsSinceEpoch(expiration))) {
      file.deleteSync();
      return null;
    }
    return data['data'];
  }

  /// Checks if a session exists in the file system, and if it has not expired.
  ///
  /// The method is synchronous and returns a boolean indicating if the session exists and is valid.
  /// If the session has expired, the method deletes the file and returns false.
  Future<bool> hasSession(String sessionId) async {
    sessionId = _makeHash(sessionId).toString();
    final file = File('$sessionPath/$sessionId');
    if (!file.existsSync()) {
      return false;
    }
    Map<String, dynamic> data = json.decode(
        VaniaEncryption.decryptString(await file.readAsString(), _secretKey));
    int expiration = data['expiration'].toString().toInt() ?? 0;
    if (!DateTime.now()
        .toUtc()
        .isBefore(DateTime.fromMillisecondsSinceEpoch(expiration))) {
      file.deleteSync();
      return false;
    }
    return true;
  }

  Future<void> deleteSession(String sessionId) async {
    sessionId = _makeHash(sessionId).toString();
    final file = File('$sessionPath/$sessionId');
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Digest _makeHash(String key) {
    var secKey = utf8.encode(_secretKey);
    var bytes = utf8.encode(key);
    var hmacSha256 = Hmac(sha256, secKey);
    return hmacSha256.convert(bytes);
  }
}
