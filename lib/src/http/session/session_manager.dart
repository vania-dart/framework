import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:vania/src/utils/functions.dart';
import 'package:vania/src/utils/helper.dart' show env;
import 'session_file_store.dart';

class SessionManager {
  HttpRequest? _request;

  String sessionKey = '${env<String>('APP_NAME', 'Vania')}_session';

  String _csrfToken = '';

  String get csrfToken => _csrfToken;

  Map<String, dynamic> _allSessions = {};

  Map<String, dynamic> get allSessions => _allSessions;

  final Duration _sessionLifeTime = Duration(
    seconds: env<int>('SESSION_LIFETIME', 9000),
  );
  bool secureSession = env<bool>('SECURE_SESSION', true);

  /// Generates a new session ID.
  ///
  /// This method creates a 64-byte random key using a secure random number generator,
  /// and encodes it using base64 URL encoding to ensure a unique and safe session ID.
  ///
  /// Returns:
  /// A base64 URL encoded string representing the session ID.
  String _generateSessionId() {
    final keyBytes = randomString(length: 64, numbers: true);
    return base64Url.encode(utf8.encode(keyBytes));
  }

  /// Creates a CSRF token and sets it as a secure cookie in the HTTP response.
  ///
  /// This function checks if an 'XSRF-TOKEN' cookie is already present in the
  /// request. If not, it generates a new random CSRF token along with an
  /// initialization vector (IV), and sets them as cookies in the response. The
  /// token and IV are also stored in the session for future validation.
  ///
  /// Parameters:
  /// - `request`: The incoming HTTP request containing the cookies.
  /// - `response`: The HTTP response where the CSRF token cookie will be added.
  ///
  /// The generated CSRF token is URL-safe and securely stored in the session with
  /// the specified session lifetime. The cookie is configured with security
  /// attributes such as domain, expiration, SameSite policy, and HTTP-only flag
  /// to mitigate CSRF attacks.
  Future<void> createXsrfToken(
    HttpRequest request,
    HttpResponse response,
  ) async {
    Cookie requestCookie = request.cookies.firstWhere(
      (cookie) => cookie.name == 'XSRF-TOKEN',
      orElse: () => Cookie('XSRF-TOKEN', ''),
    );
    if (requestCookie.value.isEmpty) {
      await _generateNewCsrfToken(response);
    } else {
      String? storedToken = _allSessions['x_csrf_token'];
      if (storedToken == null || storedToken.isEmpty) {
        await _generateNewCsrfToken(response);
      } else {
        _csrfToken = storedToken;
      }
    }
  }

  /// Generates a new CSRF token and stores it in the session and a secure cookie.
  ///
  /// This method generates a random CSRF token and initialization vector (IV),
  /// stores them in the session and a secure cookie, and sets the cookie in the
  /// response. The cookie is configured with security attributes such as
  /// expiration, SameSite policy, and HTTP-only flag to mitigate CSRF attacks.
  ///
  /// Parameters:
  /// - `response`: The HTTP response where the CSRF token cookie will be added.
  ///
  /// The generated CSRF token is URL-safe and securely stored in the session with
  /// the specified session lifetime.
  Future<void> _generateNewCsrfToken(HttpResponse response) async {
    String token = randomString(length: 40, numbers: true);
    String iv = randomString(length: 32, numbers: true);
    await setSession('x_csrf_token', token);
    await setSession('x_csrf_iv', iv);
    _csrfToken = token;
    String cookieValue = _computeCsrfCookieValue(token, iv);
    Cookie cookie = Cookie('XSRF-TOKEN', cookieValue)
      ..expires = DateTime.now().add(Duration(seconds: 9000))
      ..sameSite = SameSite.lax
      ..secure = secureSession
      ..path = '/'
      ..httpOnly = true;
    response.cookies.add(cookie);
  }

  /// Computes the value of the CSRF cookie for the given CSRF token and
  /// initialization vector (IV).

  /// The method uses the HMAC algorithm with SHA-512 to create a digest from
  /// the given token and IV. The digest is then encoded in Base64 and stored
  /// in the CSRF cookie in the response. The cookie is configured with
  /// security attributes such as expiration, SameSite policy, and HTTP-only flag
  /// to mitigate CSRF attacks.
  String _computeCsrfCookieValue(String token, String iv) {
    var hmac = Hmac(sha512, utf8.encode(iv));
    final Digest digest = hmac.convert(utf8.encode(token));
    return base64.encode(
      utf8.encode(jsonEncode({'token': base64.encode(digest.bytes)})),
    );
  }

  /// Starts a new session or retrieves an existing session from the request.
  ///
  /// This method initializes a session for the given HTTP request and response.
  /// If a sessionKey cookie is already present in the request, its value is
  /// used as the session . Otherwise, a new session is generated and set
  /// as a cookie in the response.
  ///
  /// The session  is stored in a cookie with properties configured for HTTP
  /// only access, insecure transmission (consider changing to true for secure
  /// transmission), a path set to '/', and an expiration set to the session
  /// timeout duration.
  ///
  /// Parameters:
  /// - [request]: The incoming HTTP request containing cookies.
  /// - [response]: The HTTP response where the session cookie will be added.
  ///
  /// Returns:
  /// A string representing the session.
  Future<void> sessionStart(HttpRequest request, HttpResponse response) async {
    _request = null;
    _request ??= request;
    final cookie = request.cookies.firstWhere(
      (c) => c.name == sessionKey,
      orElse: () => Cookie(sessionKey, _generateSessionId()),
    );
    String sessionId = cookie.value;

    response.cookies.add(
      Cookie(sessionKey, sessionId)
        ..httpOnly = true
        ..secure = secureSession
        ..path = '/'
        ..sameSite = SameSite.lax
        ..expires = DateTime.now().add(_sessionLifeTime),
    );

    await _featchAllSessions(sessionId);

    await createXsrfToken(request, response);
  }

  String? getSessionId() {
    final cookie = _request?.cookies.firstWhere(
      (c) => c.name == sessionKey,
      orElse: () => Cookie(sessionKey, ''),
    );
    return cookie?.value;
  }

  Future<void> _featchAllSessions(String sessionId) async {
    _allSessions = await SessionFileStore().retrieveSession(sessionId) ?? {};
  }

  Future<T> getSession<T>(String key) async {
    if (_allSessions.isEmpty) {
      final sessionId = getSessionId();
      if (sessionId != null) {
        _allSessions =
            await SessionFileStore().retrieveSession(sessionId) ?? {};
      }
    }

    if (_allSessions[key] == null) {
      return null as T;
    }

    if (T.toString() == 'int') {
      return int.tryParse(_allSessions[key].toString()) as T;
    }

    if (T.toString() == 'double') {
      return double.tryParse(_allSessions[key].toString()) as T;
    }

    if (T.toString() == 'bool') {
      return bool.tryParse(_allSessions[key].toString()) as T;
    }

    return _allSessions[key];
  }

  /// Stores a value in the session data associated with the current session ID.
  ///
  /// If a session is found, it verifies the existence and validity of the session.
  /// If the session exists, it updates the session data by adding the given key-value pair,
  /// and saves the updated session data. If the session does not exist or is invalid,
  /// it does not store the value.
  ///
  Future<void> setSession(String key, dynamic value) async {
    final sessionId = getSessionId();
    if (sessionId != null) {
      Map<String, dynamic>? session = await SessionFileStore().retrieveSession(
        sessionId,
      );
      if (session != null) {
        session.addAll({key: value});
      } else {
        session = {key: value};
      }
      _allSessions = session;
      await SessionFileStore().storeSession(sessionId, session);
    }
  }

  /// Deletes a specific key from the current session data.
  ///
  /// If a session is found, it verifies the existence and validity of the session.
  /// If the session exists, it removes the given key from the session data, and saves the
  /// updated session data. If the session does not exist or is invalid, it does not delete
  /// the key.
  ///
  /// Parameters:
  /// - [key]: The key to be deleted from the session data.
  Future<void> deleteSession(String key) async {
    final String? sessionId = getSessionId();
    if (sessionId != null) {
      Map<String, dynamic>? session = await SessionFileStore().retrieveSession(
        sessionId,
      );
      if (session != null) {
        session.remove(key);
        _allSessions = session;
        await SessionFileStore().storeSession(sessionId, session);
      }
    }
  }

  Future<void> destroyAllSessions() async {
    final sessionId = getSessionId();
    if (sessionId != null) {
      _allSessions = {};
      await SessionFileStore().storeSession(sessionId, {});
    }
  }
}
