import 'dart:async';
import 'dart:io';

/// Per-request state container that lives in the current `Zone`.
class RequestScope {
  final HttpRequest request;

  /// Session snapshot for the current request. Populated by
  /// [SessionManager.sessionStart] and read by the session helpers.
  Map<String, dynamic> sessionData = <String, dynamic>{};

  /// CSRF token currently attached to this session, if any.
  String csrfToken = '';

  /// Session id resolved from the request cookie. Cached so we don't
  /// re-scan `request.cookies` on every session helper call.
  String? sessionId;

  /// Flash-style validation errors surfaced by the current request's
  /// validators; consumed by the view engine when rendering.
  final Map<String, dynamic> sessionErrors = <String, dynamic>{};

  /// Old-input map used for form repopulation. Written by the request
  /// handler right after body extraction.
  final Map<String, dynamic> formData = <String, dynamic>{};

  /// Flash messages set via `Response.back(key, msg)` or `session()`.
  final Map<String, dynamic> flashSessions = <String, dynamic>{};

  /// Route-history state used by `Response.back()`.
  String currentRoute = '';
  String previousRoute = '';

  /// Open bag for extension packages that need per-request state without
  /// core having to know about them.
  final Map<Object, Object?> attributes = <Object, Object?>{};

  RequestScope(this.request);
}

const Object _requestScopeKey = #vania.request_scope;

/// Returns the [RequestScope] bound to the current zone, or `null` when
/// called from outside a request (background jobs, tests that render a
/// template directly, etc.).
RequestScope? get currentRequestScope {
  final v = Zone.current[_requestScopeKey];
  return v is RequestScope ? v : null;
}

/// Runs [body] with a fresh [RequestScope] bound to the current zone.
Future<T> runInRequestScope<T>(HttpRequest request, Future<T> Function() body) {
  final scope = RequestScope(request);
  return runZoned<Future<T>>(body, zoneValues: {_requestScopeKey: scope});
}
