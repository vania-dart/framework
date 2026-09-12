import 'dart:io';

import 'package:vania/env.dart' show env;

import '../../http/middleware/middleware.dart';
import '../../http/request/request.dart';

/// Sets the response headers browsers use to constrain what a page may do.
class SecurityHeaders extends Middleware {
  SecurityHeaders({
    this.contentTypeOptions = 'nosniff',
    this.frameOptions = 'DENY',
    this.referrerPolicy = 'strict-origin-when-cross-origin',
    this.contentSecurityPolicy,
    this.permissionsPolicy,
    this.strictTransportSecurity,
    this.xssProtection,
    this.removeServerHeader = true,
  });

  /// Stops the browser second-guessing `Content-Type`. Without it, a
  /// user-uploaded file served as `text/plain` can be sniffed as HTML and
  /// executed in the site's origin.
  final String? contentTypeOptions;

  /// Clickjacking protection. `DENY`, `SAMEORIGIN`, or null to omit.
  final String? frameOptions;

  /// Keeps full URLs — which routinely carry tokens and ids — out of the
  /// `Referer` sent to other origins.
  final String? referrerPolicy;

  /// Opt-in: a wrong CSP breaks the page, so there is no safe default.
  /// A reasonable starting point for a server-rendered app is
  /// `"default-src 'self'"`.
  final String? contentSecurityPolicy;

  /// Opt-in, e.g. `"geolocation=(), camera=(), microphone=()"`.
  final String? permissionsPolicy;

  /// HSTS. Only emitted over HTTPS — sending it over plain HTTP is
  /// meaningless, and browsers ignore it there. Defaults to one year plus
  /// subdomains when [APP_SECURE] is on; pass an explicit value to
  /// override, or an empty string to suppress it.
  final String? strictTransportSecurity;

  /// `X-XSS-Protection`. Defaults to null, which *removes* the header
  /// Dart sets. The legacy XSS auditor is gone from current browsers and
  /// had its own bypass-to-injection issues; CSP is the replacement.
  final String? xssProtection;

  /// Drops the `server` header, which advertises the runtime version.
  final bool removeServerHeader;

  @override
  Future<void> handle(Request req) async {
    final headers = req.response.headers;

    // A null/empty value *removes* the header rather than skipping it.
    // Dart pre-populates several of these, so "not configured" has to
    // mean "not present" — otherwise there would be no way to drop a
    // default this middleware disagrees with.
    void set(String name, String? value) {
      if (value == null || value.isEmpty) {
        headers.removeAll(name);
        return;
      }
      headers.set(name, value);
    }

    set('X-Content-Type-Options', contentTypeOptions);
    set('X-Frame-Options', frameOptions);
    set('Referrer-Policy', referrerPolicy);
    set('Content-Security-Policy', contentSecurityPolicy);
    set('Permissions-Policy', permissionsPolicy);
    set('X-XSS-Protection', xssProtection);

    if (_isSecure(req)) {
      set(
        'Strict-Transport-Security',
        strictTransportSecurity ?? 'max-age=31536000; includeSubDomains',
      );
    }

    if (removeServerHeader) {
      headers.removeAll(HttpHeaders.serverHeader);
    }
  }

  /// True when the connection reached us over TLS, either directly or
  /// through a terminating proxy that said so.
  bool _isSecure(Request req) {
    if (env<bool>('APP_SECURE', false)) return true;
    final forwardedProto = req.header('x-forwarded-proto');
    return forwardedProto != null &&
        forwardedProto.toLowerCase().startsWith('https');
  }
}
