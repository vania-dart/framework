import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:vania/src/config/config.dart';
import 'package:vania/src/exception/page_expired_exception.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/request/request.dart';
import 'package:vania/src/http/session/session_manager.dart';
import 'package:vania/src/ioc_container.dart';
import 'package:vania/src/utils/functions.dart';

import 'dart:async';

class CsrfMiddleware extends Middleware {
  final SessionManager _sessionManager =
      IoCContainer().resolve<SessionManager>();

  @override
  Future<void> handle(Request req) async {
    if (req.method?.toLowerCase() == 'post' ||
        req.method?.toLowerCase() == 'put' ||
        req.method?.toLowerCase() == 'patch') {
      List<String> csrfExcept = ['api/*'];
      csrfExcept.addAll(Config().get('csrf_except') ?? []);

      String uri =
          Uri.parse(sanitizeRoutePath(req.uri.toString())).path.toLowerCase();
      if (!_isUrlExcluded(uri, csrfExcept)) {
        String requestCookie = req.cookie('XSRF-TOKEN') ?? '';
        Map<String, dynamic> cookie = {};
        if (requestCookie.isNotEmpty) {
          cookie = jsonDecode(
              utf8.decode(base64.decode(_fixBase64Padding(requestCookie))));
        }

        String? token = req.input('_csrf') ??
            req.input('_token') ??
            req.header('X-CSRF-TOKEN');
        if (token == null || token.isEmpty) {
          throw PageExpiredException();
        }

        final storedToken =
            await _sessionManager.getSession<String?>('x_csrf_token');
        if (storedToken == null || storedToken.isEmpty) {
          throw PageExpiredException();
        }

        if (storedToken != token) {
          throw PageExpiredException();
        }

        String iv = await _sessionManager.getSession<String>('x_csrf_iv');

        String expectedCookie = _computeCsrfCookieValue(storedToken, iv);

        if (expectedCookie != cookie['token']) {
          throw PageExpiredException();
        }
      }
    }
  }

  String _fixBase64Padding(String value) {
    while (value.length % 4 != 0) {
      value += '=';
    }
    return value;
  }

  bool _isUrlExcluded(String path, List<String> csrfExcept) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    for (var pattern in csrfExcept) {
      final cleanPattern =
          pattern.startsWith('/') ? pattern.substring(1) : pattern;
      if (cleanPattern.contains('*')) {
        final regexStr =
            cleanPattern.replaceAll('*', '.*').replaceAll('/', '\\/');
        final regex = RegExp('^$regexStr\$', caseSensitive: false);
        if (regex.hasMatch(cleanPath)) {
          return true;
        }
      } else if (cleanPath
          .toLowerCase()
          .startsWith(cleanPattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  String _computeCsrfCookieValue(String token, String iv) {
    var hmac = Hmac(sha512, utf8.encode(iv));
    final Digest digest = hmac.convert(utf8.encode(token));
    return base64.encode(digest.bytes);
  }
}
