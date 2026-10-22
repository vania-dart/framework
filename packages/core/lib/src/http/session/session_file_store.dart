import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';

import '../../cryptographic/vania_encryption.dart';

import 'package:vania/env.dart' show env;
import 'package:vania/src/server/server_isolates.dart';

/// How long a session lasts after its last write, from `SESSION_LIFETIME`
/// in seconds. The cookie that carries it lasts as long.
final Duration sessionLifetime = Duration(
  seconds: env<int>('SESSION_LIFETIME', 9000),
);

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

  /// Off when several isolates serve requests: each would hold its own
  /// copy, and one isolate would serve a session another has changed.
  int get _maxCacheSize =>
      serverIsolateCount > 1 ? 0 : env<int>('SESSION_CACHE_SIZE', 5000);

  int get cacheSize => _cache.length;

  final Random _random = Random();

  String _tempSuffix() => _random.nextInt(1 << 32).toRadixString(36);

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
    Duration? duration,
  }) async {
    _maybeSweep();
    final hashedId = _makeHash(sessionId).toString();
    final file = File('$sessionPath/$hashedId');
    final expiresAt = DateTime.now().toUtc().add(duration ?? sessionLifetime);
    final sessionData = <String, dynamic>{
      'data': data,
      'expiration': expiresAt.millisecondsSinceEpoch,
    };
    final content = await VaniaEncryption.encryptString(
      json.encode(sessionData),
      _secretKey,
    );

    // Written beside the session, then renamed over it. A rename is
    // atomic, so a request reading the session meanwhile finds the old one
    // or the new one — never a file cut off halfway, which would read as
    // no session at all and sign the user out.
    final temp = File('${file.path}.tmp-${_tempSuffix()}');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(content);
    try {
      await temp.rename(file.path);
    } catch (_) {
      try {
        await temp.delete();
      } catch (_) {}
      rethrow;
    }
    _put(hashedId, _CacheEntry(Map.of(data), expiresAt));
  }

  /// Retrieves the session data, preferring the in-memory cache.
  Future<Map<String, dynamic>?> retrieveSession(String sessionId) async =>
      (await retrieveSessionEntry(sessionId))?.data;

  /// The session's data and when it expires, or null when there is none.
  Future<({Map<String, dynamic> data, DateTime expiresAt})?>
  retrieveSessionEntry(String sessionId) async {
    final hashedId = _makeHash(sessionId).toString();

    final cached = _get(hashedId);
    if (cached != null) {
      return (data: Map.of(cached.data), expiresAt: cached.expiresAt);
    }

    final file = File('$sessionPath/$hashedId');
    final Map<String, dynamic> blob;
    try {
      final decrypted = await VaniaEncryption.decryptString(
        await file.readAsString(),
        _secretKey,
      );
      if (decrypted.isEmpty) return null;
      blob = json.decode(decrypted) as Map<String, dynamic>;
    } catch (_) {
      // Missing, or unreadable — damaged, or written under another APP_KEY.
      // No session, rather than an error on every request with this cookie.
      return null;
    }
    final expiration = int.tryParse(blob['expiration'].toString()) ?? 0;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiration).toUtc();

    if (!DateTime.now().toUtc().isBefore(expiresAt)) {
      try {
        await file.delete();
      } catch (_) {}
      _cache.remove(hashedId);
      return null;
    }

    final data = Map<String, dynamic>.from(blob['data'] as Map);
    _put(hashedId, _CacheEntry(Map.of(data), expiresAt));
    return (data: data, expiresAt: expiresAt);
  }

  /// When the last sweep for expired sessions ran in this isolate.
  DateTime? _lastSweep;

  /// Deletes session files past their lifetime, and temporary files a
  /// write left behind.
  ///
  /// An expired session is otherwise only deleted when someone reads it,
  /// and most never come back: every visitor without a cookie leaves one.
  /// A file's age is read from its modified time, which is when it was
  /// last written — and every write sets a fresh expiry.
  Future<void> sweepExpired() async {
    _lastSweep = DateTime.now();
    final now = DateTime.now();
    try {
      await for (final entry in Directory(sessionPath).list()) {
        if (entry is! File) continue;
        try {
          final age = now.difference(await entry.lastModified());
          final stale = entry.path.contains('.tmp-')
              ? age > const Duration(minutes: 1)
              : age > sessionLifetime;
          if (stale) await entry.delete();
        } catch (_) {
          // Gone already, or busy: the next sweep gets it.
        }
      }
    } catch (_) {
      // No session directory yet.
    }
  }

  void _maybeSweep() {
    final last = _lastSweep;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(hours: 1)) {
      return;
    }
    unawaited(sweepExpired());
  }

  Future<bool> hasSession(String sessionId) async {
    return await retrieveSession(sessionId) != null;
  }

  /// Ends the session: its file is removed and its cache entry dropped. A
  /// request reading it at the same moment finds no session, as it should.
  Future<void> deleteSession(String sessionId) async {
    final hashedId = _makeHash(sessionId).toString();
    _cache.remove(hashedId);
    try {
      await File('$sessionPath/$hashedId').delete();
    } catch (_) {
      // Already gone.
    }
  }

  Digest _makeHash(String key) {
    final secKey = utf8.encode(_secretKey);
    final bytes = utf8.encode(key);
    return Hmac(sha256, secKey).convert(bytes);
  }
}
