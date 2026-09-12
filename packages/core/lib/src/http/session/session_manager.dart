import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania/src/utils/functions.dart';
import 'package:vania/env.dart' show env;
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

  final Duration _sessionLifeTime = Duration(
    seconds: env<int>('SESSION_LIFETIME', 9000),
  );
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
    final cookie = request.cookies.firstWhere(
      (c) => c.name == sessionKey,
      orElse: () => Cookie(sessionKey, _generateSessionId()),
    );
    final sessionId = cookie.value;

    response.cookies.add(
      Cookie(sessionKey, sessionId)
        ..httpOnly = true
        ..secure = secureSession
        ..path = '/'
        ..sameSite = SameSite.lax
        ..expires = DateTime.now().add(_sessionLifeTime),
    );

    final scope = currentRequestScope;
    if (scope != null) {
      scope.sessionId = sessionId;
      scope.sessionData =
          await SessionFileStore().retrieveSession(sessionId) ?? {};
    } else {
      _fallbackSessions =
          await SessionFileStore().retrieveSession(sessionId) ?? {};
    }

    await createXsrfToken(request, response);
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
      return scope.sessionId;
    }
    return null;
  }

  Future<T> getSession<T>(String key) async {
    final bag = allSessions;
    if (bag.isEmpty) {
      final sessionId = getSessionId();
      if (sessionId != null) {
        final hydrated =
            await SessionFileStore().retrieveSession(sessionId) ?? {};
        final scope = currentRequestScope;
        if (scope != null) {
          scope.sessionData = hydrated;
        } else {
          _fallbackSessions = hydrated;
        }
      }
    }

    final current = allSessions;
    final raw = current[key];
    if (raw == null) return null as T;

    final typeName = T.toString();
    if (typeName == 'int') return int.tryParse(raw.toString()) as T;
    if (typeName == 'double') return double.tryParse(raw.toString()) as T;
    if (typeName == 'bool') return bool.tryParse(raw.toString()) as T;
    return raw;
  }

  Future<void> setSession(String key, dynamic value) async {
    final sessionId = getSessionId();
    if (sessionId == null) return;

    Map<String, dynamic>? session = await SessionFileStore().retrieveSession(
      sessionId,
    );
    if (session != null) {
      session[key] = value;
    } else {
      session = <String, dynamic>{key: value};
    }
    final scope = currentRequestScope;
    if (scope != null) {
      scope.sessionData = session;
    } else {
      _fallbackSessions = session;
    }
    await SessionFileStore().storeSession(sessionId, session);
  }

  Future<void> deleteSession(String key) async {
    final sessionId = getSessionId();
    if (sessionId == null) return;
    final session = await SessionFileStore().retrieveSession(sessionId);
    if (session == null) return;
    session.remove(key);
    final scope = currentRequestScope;
    if (scope != null) {
      scope.sessionData = session;
    } else {
      _fallbackSessions = session;
    }
    await SessionFileStore().storeSession(sessionId, session);
  }

  Future<void> destroyAllSessions() async {
    final sessionId = getSessionId();
    if (sessionId == null) return;
    final scope = currentRequestScope;
    if (scope != null) {
      scope.sessionData = <String, dynamic>{};
    } else {
      _fallbackSessions = <String, dynamic>{};
    }
    await SessionFileStore().storeSession(sessionId, {});
  }
}
