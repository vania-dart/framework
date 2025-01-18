import 'dart:convert';

import 'package:vania/src/exception/page_expired_exception.dart';
import 'package:vania/src/utils/functions.dart';
import 'package:vania/vania.dart';

import 'dart:async';

class CsrfMiddleware extends Middleware {
  /// This middleware is used to verify the CSRF token in the request.
  ///
  /// The middleware checks if the request method is one of the [POST],[PUT],[Patch]
  /// and checks if the request URI is not in the list of excluded paths from the CSRF
  /// validation.
  ///
  /// If the request URI is not in the excluded list, then it checks if the
  /// _csrf or _token input field is present in the request, if not then it
  /// throws a PageExpiredException.
  ///
  /// If the token is present, then it verifies the token with the stored token
  /// in the session, if the verification fails then it throws a
  /// PageExpiredException.
  ///
  @override
  Future<void> handle(Request req) async {
    if (req.method!.toLowerCase() == 'post' ||
        req.method!.toLowerCase() == 'put' ||
        req.method!.toLowerCase() == 'patch') {
      List<String> csrfExcept = ['api/*'];
      csrfExcept.addAll(Config().get('csrf_except') ?? []);

      String uri = Uri.parse(
        sanitizeRoutePath(
          req.uri.toString(),
        ),
      ).path.toLowerCase();

      if (!_isUrlExcluded(uri, csrfExcept)) {
        String csrfToken = req.cookie('XSRF-TOKEN') ?? '';
        if (csrfToken.isNotEmpty) {
          csrfToken = _fixBase64Padding(csrfToken);
        }
        String? token = req.input('_csrf');
        token ??= req.input('_token');
        token ??= req.header('X-CSRF-TOKEN');

        if (token == null) {
          throw PageExpiredException();
        }

        String storedToken = await getSession<String?>('x_csrf_token') ?? '';
        if (storedToken != token) {
          throw PageExpiredException();
        }
        String iv = await getSession<String?>('x_csrf_token_iv') ?? '';
        if (!Hash().setHashKey(iv).verify(token, csrfToken)) {
          throw PageExpiredException();
        }
      }
    }
  }

  String _fixBase64Padding(String value) {
    while (value.length % 4 != 0) {
      value += '=';
    }
    return utf8.decode(base64Url.decode(value));
  }

  /// Check if the given path is excluded from CSRF validation by checking if it
  /// matches any of the patterns in the given list.
  ///
  /// The list of patterns can contain simple strings or strings with a wildcard
  /// at the end (e.g. 'api/*'). If the path matches a pattern with a wildcard
  /// then it is considered excluded.
  ///
  /// The path is considered excluded if it starts with the pattern without the
  /// wildcard or if it matches the regular expression created by replacing the
  /// wildcard with '.*'.
  ///
  /// For example, if the pattern is 'api/*' then the path will be considered
  /// excluded if it starts with '/api/' or if it matches the regular expression
  /// '^/api/.*$'.
  ///
  bool _isUrlExcluded(String path, List<String> csrfExcept) {
    for (var pattern in csrfExcept) {
      if (pattern.toLowerCase().contains('/*')) {
        final regexPattern =
            '^/${pattern.toLowerCase().replaceAll('/*', '/.*')}\$';
        final regex = RegExp(regexPattern);
        if (regex.hasMatch(path)) {
          return true;
        }
      } else if (path.startsWith(
        '/${pattern.replaceFirst('/', '').toLowerCase()}',
      )) {
        return true;
      }
    }
    return false;
  }
}
