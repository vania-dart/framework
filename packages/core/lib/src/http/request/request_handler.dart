import 'dart:convert' show htmlEscape;
import 'dart:async';
import 'dart:io';
import 'package:vania/src/extensions/extensions.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania/src/http/request/accept_query.dart';
import 'package:vania/src/http/response/error_response_writer.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/http/session/session_gate.dart';
import 'package:vania/src/http/session/session_manager.dart';
import 'package:vania/src/route/middleware/csrf_middleware.dart';
import 'package:vania/src/view_engine/template_engine.dart';

import 'package:vania/src/config/http_cors.dart';
import 'package:vania/src/exception/internal_server_error.dart';
import 'package:vania/src/exception/page_expired_exception.dart';
import 'package:vania/src/exception/not_found_exception.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/src/exception/validation_exception.dart';
import 'package:vania/src/exception/redirect_exception.dart';
import 'package:vania/src/http/controller/controller_handler.dart';
import 'package:vania/src/http/middleware/middleware_handler.dart';
import 'package:vania/src/ioc_container.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/route_history.dart';
import 'package:vania/src/route/set_static_path.dart';
import 'package:vania/src/websocket/websocket_upgrade_dispatcher.dart';
import 'package:vania/src/exception/base_http_exception.dart';
import 'package:vania/src/logger/logger.dart';
import 'package:vania/env.dart' show env;
import 'request.dart';

/// Deprecated in favor of [currentRequestScope]. Kept as an alias so
/// existing code that imported `globalHttpRequest` keeps compiling; new
/// callers should read from [currentRequestScope] directly.
///
/// Resolved from the zone-scoped [RequestScope], so concurrent requests
/// cannot observe each other's values.
HttpRequest? get globalHttpRequest => currentRequestScope?.request;

final bool _websocketEnabled = env<bool>('APP_WEBSOCKET', false);
final bool _csrfEnabled = env<bool>('CSRF_PROTECTION_ENABLED', false);
final bool _debug = () {
  try {
    return env<bool>('APP_DEBUG');
  } catch (_) {
    return false;
  }
}();

/// Longest a routed request may take to start answering, from
/// `REQUEST_TIMEOUT` in seconds; off when unset. A response already being
/// written — an event stream, a large download — runs to its end.
final Duration? _requestTimeout = () {
  final seconds = env<int>('REQUEST_TIMEOUT', 0);
  return seconds > 0 ? Duration(seconds: seconds) : null;
}();

/// A single CSRF middleware instance, attached to every state-changing
/// route. `RouteData` is shared between requests, so per-request
/// instances must never be appended to it.
final CsrfMiddleware _csrfMiddleware = CsrfMiddleware();

class RequestHandler {
  /// Handles [req] end to end. Never completes with an error: the server
  /// does not await this future, so an error escaping it would be
  /// unhandled and stop the isolate.
  Future handle(HttpRequest req) async {
    try {
      await _handle(req);
    } catch (e, stack) {
      await _fail(req, e, stack);
    }
  }

  Future<void> _handle(HttpRequest req) async {
    if (_websocketEnabled && WebSocketTransformer.isUpgradeRequest(req)) {
      // A rejected or failed upgrade must not surface as an unhandled async
      // error: the socket is hijacked by then, so there is no response left
      // to write and an uncaught error here would take the isolate down.
      try {
        await WebSocketUpgradeDispatcher().dispatch(req);
      } catch (e, stack) {
        Logger.log('WebSocket upgrade failed: $e\n$stack', type: Logger.ERROR);
      }
      return;
    }

    HttpCors().apply(req);

    if (await setStaticPathAsync(req)) return;

    final timeout = _requestTimeout;
    if (timeout == null) {
      return runInRequestScope(req, () => _handleInScope(req));
    }
    late final RequestScope scope;
    final handled = runInRequestScope(req, () {
      scope = currentRequestScope!;
      return _handleInScope(req);
    });
    // Set outside the request's zone, so the 503 it writes is not taken
    // for a late write of the abandoned request.
    final timer = Timer(timeout, () {
      if (!scope.responding) unawaited(_timedOut(req, scope, timeout));
    });
    try {
      await handled;
    } finally {
      timer.cancel();
    }
  }

  /// Answers a request that ran past `REQUEST_TIMEOUT`. The handler itself
  /// cannot be stopped and runs on, but its connection is released and
  /// nothing it does from here reaches the client or the session.
  Future<void> _timedOut(
    HttpRequest req,
    RequestScope scope,
    Duration timeout,
  ) async {
    scope.abandoned = true;
    Logger.log(
      'Request timed out after ${timeout.inSeconds}s: '
      '${req.method} ${req.uri.path}',
      type: Logger.WARNING,
    );
    await _response(req, 'Request timed out', statusCode: 503);
  }

  Future<void> _handleInScope(HttpRequest req) async {
    final acceptHeader = req.headers.value('accept') ?? '';
    // `Accept` is client-controlled, so on its own it cannot decide whether
    // to mint and persist a session. An app that ships no views never wants
    // one regardless of what the client asks for.
    final bool isHtml = acceptHeader.contains('html') && sessionsEnabled();
    try {
      final RouteData? route = matchRoute(req);
      if (route == null) return await _notFound(req, isHtml);

      // RFC 10008 §3: a QUERY resource says which media types it takes.
      final acceptQuery = route.acceptQuery;
      if (acceptQuery != null) {
        req.response.headers.set(
          'Accept-Query',
          acceptQueryHeader(acceptQuery),
        );
      }

      final DateTime? startTime = _debug ? DateTime.now() : null;

      final Request request = Request().from(request: req, route: route);

      if (isHtml) {
        await IoCContainer().resolve<SessionManager>().sessionStart(
          req,
          req.response,
        );
        RouteHistory().updateRouteHistory(req);
      }

      final List<Middleware> pre = _effectiveMiddleware(route);

      Response? response;
      var dispatched = false;
      Future<void> dispatch() async {
        dispatched = true;
        await request.extractBody();

        if (isHtml) {
          final scope = currentRequestScope;
          if (scope != null) {
            scope.formData.addAll(request.all());
          }
        }

        response = await ControllerHandler().create(
          route: route,
          request: request,
        );
      }

      if (pre.isEmpty) {
        await dispatch();
      } else {
        await middlewareHandler(pre, request, dispatch);
      }

      // A middleware may end the chain by answering itself. One that ends
      // it without answering would leave the client waiting for good.
      if (!dispatched && !_responseStarted(req.response)) {
        throw StateError(
          'A middleware ended the chain without answering: it neither '
          'called next() nor wrote a response. Middleware on this route: '
          '${pre.map((m) => m.runtimeType).join(', ')}.',
        );
      }

      // Written only now, after every middleware has finished, so one that
      // wraps the chain can still add to the response once next() returns.
      // None, when a middleware answered the request itself.
      if (response != null) {
        currentRequestScope?.responding = true;
        await response!.makeResponse(req.response);
      }

      // Normally a no-op: `Response` already ran these before writing. A
      // middleware that wrote the response itself skipped them, and a late
      // session save still beats a lost one — unless the request was
      // already answered without it.
      final scope = currentRequestScope;
      if (scope != null && !scope.abandoned) {
        final pending = scope.runBeforeResponse();
        if (pending != null) await pending;
      }

      if (_debug && startTime != null) {
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime).inMilliseconds;
        final requestUri = req.uri.path;
        final requestMethod = req.method.toUpperCase();
        final requestedPath = requestUri.isNotEmpty
            ? requestUri.padRight(118 - requestUri.length, '.')
            : ''.padRight(118, '.');
        stderr.writeln(
          '${startTime.format()} $requestMethod $requestedPath ~ ${duration}ms',
        );
      }
    } catch (error, stack) {
      if (currentRequestScope?.abandoned ?? false) {
        // Answered already; the error is the handler's own, so it is
        // still worth knowing about.
        Logger.log('$error\n$stack', type: Logger.ERROR);
        return;
      }
      await _respondToError(req, error, stack, isHtml);
    }
  }

  /// Turns an error from anywhere in a request — the router, a middleware,
  /// the controller — into its response. One policy, so the same error is
  /// answered the same way wherever it was raised.
  Future<void> _respondToError(
    HttpRequest req,
    Object error,
    StackTrace stack,
    bool isHtml,
  ) async {
    if (error is ValidationException) {
      // The errors are flashed to the session, so a browser can be sent
      // back to the form; anything else gets them here.
      return sendErrorResponse(
        req.response,
        isHtml ? Response.back() : error.response(false),
      );
    }

    if (error is! BaseHttpResponseException) {
      return _fail(req, error, stack);
    }

    // Raised on purpose, yet a failure on the server all the same.
    if (error.code >= 500) Logger.log('$error\n$stack', type: Logger.ERROR);

    if (isHtml) {
      // A redirect has to be asked for: a session guard says so with
      // `ResponseType.html` and the login page as its message. Anything
      // else — a token guard's "Unauthenticated", say — is a 401, since a
      // message is text, not an address to send the browser to.
      final redirects =
          error is RedirectException ||
          (error is Unauthenticated && error.responseType == ResponseType.html);
      if (redirects) {
        return sendErrorResponse(
          req.response,
          Response.redirect('${error.message}'),
        );
      }
      final page = switch (error) {
        NotFoundException() => 'errors/404',
        InternalServerError() => 'errors/500',
        PageExpiredException() => 'errors/419',
        _ => null,
      };
      final rendered = page == null ? null : _errorPage(page, error.code);
      if (rendered != null) return sendErrorResponse(req.response, rendered);
    }

    // A 5xx message may describe internals, so it is shown only in debug.
    if (error.code >= 500) {
      return _response(
        req,
        _publicMessage('${error.message}'),
        statusCode: error.code,
      );
    }
    await sendErrorResponse(req.response, error.response(isHtml));
  }

  /// Answers a request that matches no route. Unmatched paths are common,
  /// so this is reached by value rather than by throwing.
  Future<void> _notFound(HttpRequest req, bool isHtml) async {
    if (req.method.toUpperCase() == 'OPTIONS') {
      // A preflight for a path with no route of its own; the CORS headers
      // are already on the response. `Allow` says what the path takes —
      // how a client finds out whether it supports QUERY.
      final routes = routesForPath(req);
      final headers = req.response.headers;
      if (routes.isNotEmpty) {
        headers.set(
          HttpHeaders.allowHeader,
          [
            for (final route in routes) ...[
              route.method.toUpperCase(),
              if (route.method == 'get') 'HEAD',
            ],
            'OPTIONS',
          ].join(', '),
        );
      }
      for (final route in routes) {
        final acceptQuery = route.acceptQuery;
        if (acceptQuery != null) {
          headers.set('Accept-Query', acceptQueryHeader(acceptQuery));
        }
      }
      headers.contentLength = 0;
      await req.response.close();
      return;
    }
    final rendered = isHtml ? _errorPage('errors/404', 404) : null;
    if (rendered != null) return sendErrorResponse(req.response, rendered);
    await routeNotFound().response(isHtml).makeResponse(req.response);
  }

  /// Whether [res] has gone out, at least its headers. dart:io has no
  /// direct way to ask; once the headers are sent, the status can no
  /// longer be set.
  static bool _responseStarted(HttpResponse res) {
    try {
      res.statusCode = res.statusCode;
      return false;
    } on StateError {
      return true;
    }
  }

  /// The app's own page for an error, such as `errors/404`, sent with the
  /// error's [statusCode] — a 404 page answered with 200 tells crawlers and
  /// monitoring that all is well. Null when the app has no such page.
  Response? _errorPage(String page, int statusCode) {
    if (!File('lib/resources/view/$page.html').existsSync()) return null;
    return Response.html(TemplateEngine().render(page), statusCode: statusCode);
  }

  /// Returns the effective pre-middleware list for [route] without
  /// mutating the cached RouteData. If CSRF is disabled or the route
  /// already has no middleware, the caller receives the route's own
  /// list back unchanged (no allocation).
  List<Middleware> _effectiveMiddleware(RouteData route) {
    if (!_csrfEnabled) return route.preMiddleware;

    // CSRF only applies to state-changing methods. For everything else
    // the route's own list is fine.
    if (!CsrfMiddleware.protectedMethods.contains(route.method)) {
      return route.preMiddleware;
    }

    // Avoid double-inserting when the app already registered CSRF
    // explicitly.
    for (final m in route.preMiddleware) {
      if (identical(m, _csrfMiddleware) || m is CsrfMiddleware) {
        return route.preMiddleware;
      }
    }

    // First, so a forged request is turned away before any of the app's
    // own middleware acts on it.
    return <Middleware>[_csrfMiddleware, ...route.preMiddleware];
  }

  /// Logs an internal failure with its stack trace and replies without
  /// leaking the underlying message unless APP_DEBUG is on.
  Future<void> _fail(HttpRequest req, Object error, StackTrace stack) async {
    Logger.log('$error\n$stack', type: Logger.ERROR);
    await _response(req, _publicMessage('$error'));
  }

  /// [detail] in debug mode, and a generic message otherwise: errors from
  /// drivers and the like routinely carry SQL, paths and other internals.
  String _publicMessage(String detail) =>
      env<bool>('APP_DEBUG', false) ? detail : 'Internal Server Error';

  Future<void> _response(
    HttpRequest req,
    String message, {
    int statusCode = 500,
  }) async {
    // HTML on the same terms as every other answer: the client asks for it
    // and the app renders pages at all. An API answers in JSON.
    final html =
        (req.headers.value('accept') ?? '').contains('html') &&
        sessionsEnabled();
    final response = html
        ? Response.html(htmlEscape.convert(message), statusCode: statusCode)
        : Response.json({"message": message}, statusCode);
    await sendErrorResponse(req.response, response);
  }
}
