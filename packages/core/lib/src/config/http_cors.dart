import 'dart:io';

import '../ioc_container.dart';
import 'config.dart';

/// Applies the configured CORS headers to an outgoing response.
///
/// `origin` may be:
///
///   * a single origin — `'https://app.example'`
///   * a list of origins — the request's `Origin` is matched against the
///     list and echoed back when it appears there
///   * `'*'` — any origin
///
/// When a list is configured, `Vary: Origin` is emitted so shared caches
/// do not serve one origin's response to another.
///
/// `Access-Control-Allow-Origin: *` cannot be combined with
/// `credentials: true` — browsers reject that pairing — so the
/// combination raises a [StateError] rather than producing a response no
/// browser will accept.
class HttpCors {
  HttpCors.createDefault();

  factory HttpCors() =>
      IoCContainer().resolveOrDefault<HttpCors>(HttpCors.createDefault);

  CORSConfig? _cached;
  bool _resolved = false;

  /// Writes the CORS headers for [req] onto its response.
  void apply(HttpRequest req) {
    if (!_resolved) {
      _cached = Config().get('cors');
      _resolved = true;
    }
    final cors = _cached;
    if (cors == null || !cors.enabled) return;

    final h = req.response.headers;
    final requestOrigin = req.headers.value('origin');

    final allowOrigin = _resolveOrigin(cors, requestOrigin, h);
    if (allowOrigin != null) {
      _add(h, HttpHeaders.accessControlAllowOriginHeader, allowOrigin);
    }

    _add(h, HttpHeaders.accessControlAllowMethodsHeader, cors.methods);
    _add(h, HttpHeaders.accessControlAllowHeadersHeader, cors.headers);
    _add(h, HttpHeaders.accessControlExposeHeadersHeader, cors.exposeHeaders);
    _add(h, HttpHeaders.accessControlAllowCredentialsHeader, cors.credentials);
    _add(h, HttpHeaders.accessControlMaxAgeHeader, cors.maxAge);
  }

  /// Works out which origin to allow, adding `Vary: Origin` when the
  /// answer depends on the request.
  String? _resolveOrigin(
    CORSConfig cors,
    String? requestOrigin,
    HttpHeaders responseHeaders,
  ) {
    final configured = cors.origin;
    if (configured == null) return null;

    if (configured is List) {
      responseHeaders.add(HttpHeaders.varyHeader, 'Origin');
      if (requestOrigin == null) return null;

      final allowed = configured
          .map((e) => e.toString().trim().toLowerCase())
          .toList();
      if (allowed.contains('*')) {
        _assertNoCredentialWildcard(cors);
        return '*';
      }
      return allowed.contains(requestOrigin.trim().toLowerCase())
          ? requestOrigin
          : null;
    }

    final single = configured.toString();
    if (single == '*') _assertNoCredentialWildcard(cors);
    return single;
  }

  void _assertNoCredentialWildcard(CORSConfig cors) {
    if (cors.credentials == true) {
      throw StateError(
        'CORS is configured with origin "*" and credentials: true. '
        'Browsers reject that combination — list the allowed origins '
        'explicitly instead.',
      );
    }
  }

  /// Writes [value] under [key], skipping null and empty values.
  void _add(HttpHeaders h, String key, dynamic value) {
    if (value == null) return;
    if (value is List<String>) {
      if (value.isEmpty) return;
      h.add(key, value.join(','));
      return;
    }
    if (value is String) {
      if (value.isEmpty) return;
      h.add(key, value);
      return;
    }
    h.add(key, value.toString());
  }
}
