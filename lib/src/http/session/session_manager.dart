import 'dart:convert';
import 'dart:io';
import 'package:vania/src/utils/functions.dart';
import 'package:vania/vania.dart';
import 'session_file_store.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  HttpRequest? _request;

  String sessionKey = '${env<String>('APP_NAME', 'Vania')}_session';

  String _csrfToken = '';

  String get csrfToken => _csrfToken;

  final Duration _sessionLifeTime =
      Duration(seconds: env<int>('SESSION_LIFETIME', 9000));
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
    final cookie = request.cookies.firstWhere(
      (c) => c.name == 'XSRF-TOKEN',
      orElse: () => Cookie('XSRF-TOKEN', ''),
    );
    String token = cookie.value;
    String? storedToken = await getSession<String?>('x_csrf_token');

    if (token.isEmpty || storedToken == null) {
      await generateNewToken(response);
    }
  }

  Future<void> generateNewToken(HttpResponse response) async {
    String token = randomString(length: 40, numbers: true);
    String iv = randomString(length: 32, numbers: true);
    await setSession('x_csrf_token_iv', iv);
    await setSession('x_csrf_token', token);
    _csrfToken = token;
    token = Hash().setHashKey(iv).make(token);
    response.cookies.add(
      Cookie('XSRF-TOKEN', base64Url.encode(utf8.encode(token)))
        ..expires = DateTime.now().add(Duration(seconds: 9000))
        ..sameSite = SameSite.lax
        ..secure = secureSession
        ..path = '/'
        ..httpOnly = true,
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
  Future<void> sessionStart(
    HttpRequest request,
    HttpResponse response,
  ) async {
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

    _request?.cookies.add(
      Cookie(sessionKey, sessionId)
        ..httpOnly = true
        ..secure = secureSession
        ..path = '/'
        ..sameSite = SameSite.lax
        ..expires = DateTime.now().add(_sessionLifeTime),
    );

    _csrfToken = await getSession<String?>('x_csrf_token') ?? '';
    await createXsrfToken(request, response);
  }

  String? getSessionId() {
    final cookie = _request?.cookies.firstWhere(
      (c) => c.name == sessionKey,
      orElse: () => Cookie(sessionKey, ''),
    );
    return cookie?.value;
  }

  /// Retrieves all session data associated with the current session ID.
  ///
  /// This function checks if there is an active session by retrieving the
  /// If a session is found, it verifies the existence and
  /// validity of the session. If the session exists, it retrieves and returns
  /// the session data as a map. If the session does not exist or is invalid,
  /// it returns null.
  ///
  /// Returns:
  /// A map containing the session data if a valid session exists, otherwise
  /// returns null.
  Future<Map<String, dynamic>?> allSessions() async {
    final sessionId = getSessionId();
    if (sessionId != null) {
      if (!await SessionFileStore().hasSession(sessionId)) {
        return null;
      }
      Map<String, dynamic> session = {};

      session = await SessionFileStore().retrieveSession(sessionId) ?? {};
      return session;
    }
    return null;
  }

  Future<T> getSession<T>(String key) async {
    Map<String, dynamic>? session = await allSessions();

    if (session?[key] == null) {
      return null as T;
    }

    if (T.toString() == 'int') {
      return int.tryParse(session?[key].toString() ?? '') as T;
    }

    if (T.toString() == 'double') {
      return double.tryParse(session?[key].toString() ?? '') as T;
    }

    if (T.toString() == 'bool') {
      return bool.tryParse(session?[key].toString() ?? '') as T;
    }

    return session?[key];
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
      Map<String, dynamic> session =
          await SessionFileStore().retrieveSession(sessionId) ?? {};
      session.addAll({key: value});
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
      Map<String, dynamic> session =
          await SessionFileStore().retrieveSession(sessionId) ?? {};
      session.remove(key);
      await SessionFileStore().storeSession(sessionId, session);
    }
  }

  Future<void> destroyAllSessions() async {
    final sessionId = getSessionId();
    if (sessionId != null) {
      await SessionFileStore().storeSession(sessionId, {});
    }
  }
}
