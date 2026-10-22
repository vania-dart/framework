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

  /// Whether [sessionData] has been read from the session store.
  bool sessionLoaded = false;

  /// Set when the handler starts writing its response. From then on
  /// `REQUEST_TIMEOUT` leaves the request alone: it limits how long the
  /// app takes to answer, not how long a stream or a download runs.
  bool responding = false;

  /// Set once the request has been answered without its handler — by
  /// `REQUEST_TIMEOUT`. The handler cannot be stopped, but whatever it
  /// goes on to write or save is dropped: the client has its answer.
  bool abandoned = false;

  List<Future<void> Function()>? _beforeResponse;

  RequestScope(this.request);

  /// Registers [task] to finish before this request's response is written.
  ///
  /// For writes the next request from the same client must see — a
  /// session save, above all: once the response is out, the browser may
  /// already be following its redirect.
  void beforeResponse(Future<void> Function() task) {
    (_beforeResponse ??= <Future<void> Function()>[]).add(task);
  }

  /// Runs the tasks registered with [beforeResponse], each once.
  ///
  /// `Response.makeResponse` calls this before writing; the request
  /// handler calls it again when the request ends, for a response written
  /// some other way.
  ///
  /// Returns null when there is nothing to run, so the common case costs
  /// the caller no `await`.
  Future<void>? runBeforeResponse() {
    if (_beforeResponse == null) return null;
    return _runAll();
  }

  Future<void> _runAll() async {
    // A task may register another: saving flashed messages writes to the
    // session, whose own save then has to follow.
    for (var tasks = _beforeResponse; tasks != null; tasks = _beforeResponse) {
      _beforeResponse = null;
      for (final task in tasks) {
        await task();
      }
    }
  }
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
