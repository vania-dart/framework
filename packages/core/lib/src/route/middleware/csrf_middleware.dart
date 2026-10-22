import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:vania/http/response.dart';
import 'package:vania/src/config/config.dart';
import 'package:vania/src/cryptographic/secure_compare.dart';
import 'package:vania/src/exception/page_expired_exception.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/session/session_manager.dart';
import 'package:vania/src/ioc_container.dart';
import 'package:vania/src/utils/functions.dart';

/// Verifies CSRF tokens for state-changing requests.
///
/// Checks are ordered cheapest-first: a missing cookie, a missing session
/// token or an excluded URL is resolved before the body is read. The body
/// is only materialised — to compare the `_csrf`/`_token` field — once the
/// request-side checks have passed, so a request without a token cannot
/// make the server buffer a large payload before being rejected.
///
/// Token comparisons are constant-time.
class CsrfMiddleware extends Middleware {
  final SessionManager _sessionManager = IoCContainer()
      .resolve<SessionManager>();

  /// The methods that change state, and so need a token. The request
  /// handler attaches this middleware to routes by the same set, so the
  /// two cannot disagree about which requests are checked.
  static const Set<String> protectedMethods = {
    'post',
    'put',
    'patch',
    'delete',
  };

  @override
  Future<void> handle(Request req) async {
    if (!protectedMethods.contains(req.method?.toLowerCase())) return;

    // `api/*` is excluded by default: API routes are normally
    // token-authenticated, where CSRF does not apply. Apps that
    // authenticate `/api/*` with the session cookie should set
    // `csrf_protect_api: true` to drop the default.
    final protectApi = Config().get('csrf_protect_api') == true;
    final excluded = <String>[
      if (!protectApi) 'api/*',
      ...?Config().get('csrf_except'),
    ];
    final uri = Uri.parse(
      sanitizeRoutePath(req.uri.toString()),
    ).path.toLowerCase();
    if (_isUrlExcluded(uri, excluded)) return;

    // Fail-fast checks: none of these touch the request body.
    final requestCookie = req.cookie<String>('XSRF-TOKEN') ?? '';
    if (requestCookie.isEmpty) _reject(req);

    final storedToken = await _sessionManager.getSession<String?>(
      'x_csrf_token',
    );
    if (storedToken == null || storedToken.isEmpty) _reject(req);

    final iv = await _sessionManager.getSession<String>('x_csrf_iv');
    final expectedCookieValue = _computeCsrfCookieValue(storedToken, iv);

    // The cookie is fully client-controlled, so a malformed one must be
    // an ordinary CSRF rejection rather than a decode error: any other
    // outcome distinguishes "bad cookie" from "wrong token".
    final cookieToken = _decodeCookieToken(requestCookie);
    if (cookieToken == null) _reject(req);
    if (!secureEquals(expectedCookieValue, cookieToken)) _reject(req);

    // Cookie/session pair verified. Now materialize the body — worst case
    // an attacker still had to supply a valid stolen cookie + session
    // combination to force us here.
    await req.extractBody();

    final submitted =
        req.input('_csrf') ?? req.input('_token') ?? req.header('X-CSRF-TOKEN');
    if (submitted == null || submitted.toString().isEmpty) _reject(req);
    if (!secureEquals(submitted.toString(), storedToken)) _reject(req);
  }

  /// Returns the `token` field from the XSRF cookie, or null if the
  /// cookie is not decodable base64, not valid UTF-8, not a JSON object,
  /// or carries no string `token`.
  String? _decodeCookieToken(String rawCookie) {
    try {
      final decoded = jsonDecode(
        utf8.decode(base64.decode(_fixBase64Padding(rawCookie))),
      );
      if (decoded is! Map) return null;
      final token = decoded['token'];
      return token is String ? token : null;
    } catch (_) {
      return null;
    }
  }

  Never _reject(Request req) {
    if (req.isJson()) {
      throw PageExpiredException(
        message: 'Security Error: The CSRF token is missing or incorrect',
        responseType: ResponseType.json,
      );
    }
    throw PageExpiredException();
  }

  String _fixBase64Padding(String value) {
    while (value.length % 4 != 0) {
      value += '=';
    }
    return value;
  }

  /// Whether [path] is one `csrf_except` leaves out.
  ///
  /// A pattern names a path and everything under it — `webhooks` covers
  /// `webhooks/stripe`, not `webhooks-admin`. In a pattern with `*`, the
  /// `*` matches anything and every other character only itself.
  bool _isUrlExcluded(String path, List<String> csrfExcept) {
    final cleanPath = (path.startsWith('/') ? path.substring(1) : path)
        .toLowerCase();
    for (final pattern in csrfExcept) {
      final cleanPattern =
          (pattern.startsWith('/') ? pattern.substring(1) : pattern)
              .toLowerCase();
      if (cleanPattern.contains('*')) {
        final regex = RegExp(
          '^${RegExp.escape(cleanPattern).replaceAll(r'\*', '.*')}\$',
        );
        if (regex.hasMatch(cleanPath)) return true;
      } else if (cleanPath == cleanPattern ||
          cleanPath.startsWith('$cleanPattern/')) {
        return true;
      }
    }
    return false;
  }

  String _computeCsrfCookieValue(String token, String iv) {
    final hmac = Hmac(sha512, utf8.encode(iv));
    final digest = hmac.convert(utf8.encode(token));
    return base64.encode(digest.bytes);
  }
}
