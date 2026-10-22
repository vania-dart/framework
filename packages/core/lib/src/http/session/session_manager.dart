import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania/src/utils/functions.dart';
import 'package:vania/env.dart' show env;
import 'flash_messages.dart';
import 'session_file_store.dart';

/// Session lifecycle owner.
class SessionManager {
  String sessionKey = '${env<String>('APP_NAME', 'Vania')}_session';

  /// Fallback CSRF token slot used when a caller reaches [csrfToken]
  /// from outside a request scope (should not happen in production).
  String _fallbackCsrfToken = '';

  /// Fallback session bag used from outside a request scope.
  Map<String, dynamic> _fallbackSessions = <String, dynamic>{};

  String get csrfToken => currentRequestScope?.csrfToken ?? _fallbackCsrfToken;

  Map<String, dynamic> get allSessions =>
      currentRequestScope?.sessionData ?? _fallbackSessions;

  bool secureSession = env<bool>('SECURE_SESSION', true);

  String _generateSessionId() {
    final keyBytes = randomString(length: 64, numbers: true);
    return base64Url.encode(utf8.encode(keyBytes));
  }

  Future<void> createXsrfToken(
    HttpRequest request,
    HttpResponse response,
  ) async {
    final requestCookie = request.cookies.firstWhere(
      (cookie) => cookie.name == 'XSRF-TOKEN',
      orElse: () => Cookie('XSRF-TOKEN', ''),
    );
    if (requestCookie.value.isEmpty) {
      await _generateNewCsrfToken(response);
    } else {
      final storedToken = allSessions['x_csrf_token'];
      if (storedToken == null || storedToken.toString().isEmpty) {
        await _generateNewCsrfToken(response);
      } else {
        _setCsrfToken(storedToken.toString());
      }
    }
  }

  void _setCsrfToken(String token) {
    final scope = currentRequestScope;
    if (scope != null) {
      scope.csrfToken = token;
    } else {
      _fallbackCsrfToken = token;
    }
  }

  Future<void> _generateNewCsrfToken(HttpResponse response) async {
    final token = randomString(length: 40, numbers: true);
    final iv = randomString(length: 32, numbers: true);
    await setSession('x_csrf_token', token);
    await setSession('x_csrf_iv', iv);
    _setCsrfToken(token);
    final cookieValue = _computeCsrfCookieValue(token, iv);
    final cookie = Cookie('XSRF-TOKEN', cookieValue)
      ..expires = DateTime.now().add(const Duration(seconds: 9000))
      ..sameSite = SameSite.lax
      ..secure = secureSession
      ..path = '/'
      ..httpOnly = true;
    response.cookies.add(cookie);
  }

  String _computeCsrfCookieValue(String token, String iv) {
    final hmac = Hmac(sha512, utf8.encode(iv));
    final Digest digest = hmac.convert(utf8.encode(token));
    return base64.encode(
      utf8.encode(jsonEncode({'token': base64.encode(digest.bytes)})),
    );
  }

  /// Starts a session for [request], writing the session cookie on
  /// [response] and hydrating [RequestScope.sessionData] from disk.
  Future<void> sessionStart(HttpRequest request, HttpResponse response) async {
    final presented = request.cookies
        .where((c) => c.name == sessionKey && c.value.isNotEmpty)
        .firstOrNull
        ?.value;
    final stored = presented == null
        ? null
        : await SessionFileStore().retrieveSessionEntry(presented);
    // An id with no session behind it — one the server never issued, or
    // one whose session has ended — is not taken up. Otherwise whoever put
    // it in the browser would know the id of the session its user is about
    // to sign in to.
    final sessionId = stored != null ? presented! : _generateSessionId();
    _setSessionCookie(response, sessionId);

    final scope = currentRequestScope;
    if (scope != null) {
      scope.sessionId = sessionId;
      scope.sessionData = stored?.data ?? {};
      scope.sessionLoaded = true;
      // A session in use is kept alive. Rewriting it on every request
      // would cost a write each time, so it is renewed once past half its
      // lifetime: at most two writes per lifetime, and an active user is
      // never signed out.
      if (stored != null &&
          stored.expiresAt.difference(DateTime.now()) < sessionLifetime ~/ 2) {
        (await _changesFor(scope))?.renew = true;
      }
      await FlashMessages.restore(scope, this);
    } else {
      _fallbackSessions = stored?.data ?? {};
    }

    await createXsrfToken(request, response);
  }

  void _setSessionCookie(HttpResponse response, String sessionId) {
    response.cookies
      ..removeWhere((c) => c.name == sessionKey)
      ..add(
        Cookie(sessionKey, sessionId)
          ..httpOnly = true
          ..secure = secureSession
          ..path = '/'
          ..sameSite = SameSite.lax
          ..expires = DateTime.now().add(sessionLifetime),
      );
  }

  /// Moves the session to a new id, keeping its data, and ends the old one.
  ///
  /// Call it when a user signs in, and whenever their privileges change.
  /// An id someone else may have learned before — planted in the browser,
  /// or read off an unencrypted connection — then leads nowhere, instead
  /// of into the signed-in session.
  Future<void> regenerateSession() async {
    final scope = currentRequestScope;
    final oldId = getSessionId();
    if (scope == null || oldId == null) return;
    await _load(scope, oldId);

    // Whatever this request changed so far is in sessionData already; it
    // all goes to the new id instead.
    final pending = scope.attributes[_SessionChanges];
    if (pending is _SessionChanges) pending.discarded = true;

    final newId = _generateSessionId();
    scope.sessionId = newId;
    scope.attributes.remove(_Unchecked);
    _setSessionCookie(scope.request.response, newId);
    final changes = _SessionChanges(scope, newId, replaces: oldId)
      ..cleared = true
      ..values.addAll(scope.sessionData);
    scope.attributes[_SessionChanges] = changes;
    scope.beforeResponse(changes.save);
  }

  /// Resolves the session id for the current request from the
  /// zone-scoped scope, or from the request cookies as a fallback.
  String? getSessionId() {
    final scope = currentRequestScope;
    if (scope != null) {
      if (scope.sessionId != null) return scope.sessionId;
      final cookie = scope.request.cookies.firstWhere(
        (c) => c.name == sessionKey,
        orElse: () => Cookie(sessionKey, ''),
      );
      scope.sessionId = cookie.value.isEmpty ? null : cookie.value;
      // Taken from the cookie as it is: whether the server issued it is
      // found out when the session is read.
      if (scope.sessionId != null) scope.attributes[_Unchecked] = true;
      return scope.sessionId;
    }
    return null;
  }

  Future<T> getSession<T>(String key) async {
    final scope = currentRequestScope;
    final sessionId = getSessionId();
    if (scope != null && sessionId != null) await _load(scope, sessionId);

    final raw = allSessions[key];
    if (raw == null) return null as T;

    final typeName = T.toString();
    if (typeName == 'int') return int.tryParse(raw.toString()) as T;
    if (typeName == 'double') return double.tryParse(raw.toString()) as T;
    if (typeName == 'bool') return bool.tryParse(raw.toString()) as T;
    return raw;
  }

  /// Sets [key] for the rest of this request, and in the store before the
  /// response is written.
  Future<void> setSession(String key, dynamic value) async {
    final changes = await _changesFor(currentRequestScope);
    if (changes == null) return;
    changes.scope.sessionData[key] = value;
    changes.values[key] = value;
  }

  Future<void> deleteSession(String key) async {
    final changes = await _changesFor(currentRequestScope);
    if (changes == null) return;
    changes.scope.sessionData.remove(key);
    changes.values[key] = _removed;
  }

  Future<void> destroyAllSessions() async {
    final changes = await _changesFor(currentRequestScope);
    if (changes == null) return;
    changes.scope.sessionData = <String, dynamic>{};
    changes.values.clear();
    changes.cleared = true;
  }

  Future<void> _load(RequestScope scope, String sessionId) async {
    if (scope.sessionLoaded) return;
    final stored = await SessionFileStore().retrieveSession(sessionId);
    scope.sessionData = stored ?? {};
    scope.sessionLoaded = true;
    if (stored != null) scope.attributes.remove(_Unchecked);
  }

  /// The pending changes for this request's session, registering their
  /// save on first use. Null outside a request or without a session.
  Future<_SessionChanges?> _changesFor(RequestScope? scope) async {
    var sessionId = getSessionId();
    if (scope == null || sessionId == null) return null;
    final existing = scope.attributes[_SessionChanges];
    if (existing is _SessionChanges) return existing;

    await _load(scope, sessionId);
    if (scope.attributes.remove(_Unchecked) != null) {
      // The cookie names no session. Writing one under that id would let
      // whoever put it in the browser into the session — a request that
      // never went through [sessionStart], such as a `fetch` to an API
      // route, takes the cookie as it is. A new id is issued instead.
      sessionId = _generateSessionId();
      try {
        _setSessionCookie(scope.request.response, sessionId);
      } on StateError {
        // The response has gone out, so the client could not be told the
        // new id: there is nothing to save the changes under.
        return null;
      }
      scope.sessionId = sessionId;
    }
    final changes = _SessionChanges(scope, sessionId);
    scope.attributes[_SessionChanges] = changes;
    scope.beforeResponse(changes.save);
    return changes;
  }
}

/// Marks a key deleted in [_SessionChanges.values].
const Object _removed = Object();

/// Key of the [RequestScope.attributes] flag set while the request's
/// session id is one read from its cookie and not yet found in the store.
abstract final class _Unchecked {}

/// The session writes one request makes, saved together once.
///
/// Only the keys this request touched are written, onto the stored
/// session as it stands at save time. Saving the request's whole copy
/// instead would undo whatever a concurrent request from the same client
/// wrote in the meantime — a login, say, made in another tab.
class _SessionChanges {
  final RequestScope scope;
  final String sessionId;

  /// Changed keys in the order they were changed; [_removed] for deletes.
  final Map<String, Object?> values = <String, Object?>{};

  /// Whether the session was emptied before [values] were made.
  bool cleared = false;

  /// Whether to write the session even with nothing changed, to give it a
  /// fresh expiry.
  bool renew = false;

  /// Set when the session moved to a new id before this could be saved.
  bool discarded = false;

  /// The id this session moves from; that session ends once this is saved.
  final String? replaces;

  _SessionChanges(this.scope, this.sessionId, {this.replaces});

  Future<void> save() async {
    // Changes made from here on start a fresh set with a save of its own.
    if (identical(scope.attributes[_SessionChanges], this)) {
      scope.attributes.remove(_SessionChanges);
    }
    if (discarded || (!cleared && !renew && values.isEmpty)) return;
    final store = SessionFileStore();
    final stored = cleared ? null : await store.retrieveSession(sessionId);
    final session = stored ?? <String, dynamic>{};
    values.forEach((key, value) {
      if (identical(value, _removed)) {
        session.remove(key);
      } else {
        session[key] = value;
      }
    });
    if (stored == null && !cleared && session.isEmpty) return;
    await store.storeSession(sessionId, session);
    final old = replaces;
    if (old != null) await store.deleteSession(old);
  }
}
