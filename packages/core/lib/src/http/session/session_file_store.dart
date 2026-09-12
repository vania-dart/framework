import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

import '../../cryptographic/vania_encryption.dart';

import 'package:vania/env.dart' show env;

/// One entry in the in-memory LRU cache.
class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime expiresAt;
  _CacheEntry(this.data, this.expiresAt);
}

/// File-backed session store with an in-memory LRU cache in front of the
/// disk layer.
class SessionFileStore {
  static final SessionFileStore _singleton = SessionFileStore._internal();
  factory SessionFileStore() => _singleton;
  SessionFileStore._internal();

  final String _secretKey = env('APP_KEY');

  /// Directory session files are written to. Tests relocate it rather than
  /// moving the process working directory, which is shared by every test
  /// file running concurrently.
  String sessionPath = 'storage/framework/sessions';

  /// LRU: insertion order is refresh order. On get, remove-and-reinsert to
  /// move the entry to the tail (most-recently-used).
  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};
  int get _maxCacheSize => env<int>('SESSION_CACHE_SIZE', 5000);

  int get cacheSize => _cache.length;

  String filePathFor(String sessionId) =>
      '$sessionPath/${_makeHash(sessionId)}';

  void invalidateCache([String? sessionId]) {
    if (sessionId == null) {
      _cache.clear();
    } else {
      _cache.remove(_makeHash(sessionId).toString());
    }
  }

  void _put(String hashedId, _CacheEntry entry) {
    // Move-to-end semantics for LRU.
    _cache.remove(hashedId);
    _cache[hashedId] = entry;
    while (_cache.length > _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  _CacheEntry? _get(String hashedId) {
    final entry = _cache.remove(hashedId);
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      return null; // expired — treat as miss
    }
    _cache[hashedId] = entry; // refresh position
    return entry;
  }

  /// Stores session data on disk (encrypted) and warms the in-memory cache.
  Future<void> storeSession(
    String sessionId,
    Map<String, dynamic> data, {
    Duration duration = const Duration(hours: 1),
  }) async {
    final hashedId = _makeHash(sessionId).toString();
    final file = File('$sessionPath/$hashedId');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    final expiresAt = DateTime.now().toUtc().add(duration);
    final sessionData = <String, dynamic>{
      'data': data,
      'expiration': expiresAt.millisecondsSinceEpoch,
    };
    final content = await VaniaEncryption.encryptString(
      json.encode(sessionData),
      _secretKey,
    );

    final raf = await file.open(mode: FileMode.write);
    try {
      await raf.writeFrom(utf8.encode(content));
    } finally {
      try {
        await raf.unlock();
      } catch (_) {}
      await raf.close();
    }
    _put(hashedId, _CacheEntry(Map.of(data), expiresAt));
  }

  /// Retrieves the session data, preferring the in-memory cache.
  Future<Map<String, dynamic>?> retrieveSession(String sessionId) async {
    final hashedId = _makeHash(sessionId).toString();

    final cached = _get(hashedId);
    if (cached != null) return Map.of(cached.data);

    final file = File('$sessionPath/$hashedId');
    if (!await file.exists()) return null;
    final raf = await file.open(mode: FileMode.read);
    String fileContent = '';
    try {
      final length = await raf.length();
      fileContent = utf8.decode(await raf.read(length));
    } finally {
      try {
        await raf.unlock();
      } catch (_) {}
      await raf.close();
    }

    final decrypted = await VaniaEncryption.decryptString(
      fileContent,
      _secretKey,
    );
    if (decrypted.isEmpty) return null;
    final blob = json.decode(decrypted) as Map<String, dynamic>;
    final expiration = int.tryParse(blob['expiration'].toString()) ?? 0;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiration).toUtc();

    if (!DateTime.now().toUtc().isBefore(expiresAt)) {
      await file.delete();
      _cache.remove(hashedId);
      return null;
    }

    final data = Map<String, dynamic>.from(blob['data'] as Map);
    _put(hashedId, _CacheEntry(Map.of(data), expiresAt));
    return data;
  }

  Future<bool> hasSession(String sessionId) async {
    return await retrieveSession(sessionId) != null;
  }

  /// Marks the session as deleted by writing an expired blob and clearing
  /// the cache entry. The file is left on disk (rewriteable) so concurrent
  /// readers don't race with unlink.
  Future<void> deleteSession(String sessionId) async {
    final hashedId = _makeHash(sessionId).toString();
    _cache.remove(hashedId);
    final file = File('$sessionPath/$hashedId');
    if (await file.exists()) {
      final raf = await file.open(mode: FileMode.write);
      try {
        final expiration = DateTime.now().toUtc().millisecondsSinceEpoch - 1;
        final content = await VaniaEncryption.encryptString(
          json.encode({'data': <String, dynamic>{}, 'expiration': expiration}),
          _secretKey,
        );
        await raf.writeFrom(utf8.encode(content));
      } finally {
        try {
          await raf.unlock();
        } catch (_) {}
        await raf.close();
      }
    }
  }

  Digest _makeHash(String key) {
    final secKey = utf8.encode(_secretKey);
    final bytes = utf8.encode(key);
    return Hmac(sha256, secKey).convert(bytes);
  }
}
