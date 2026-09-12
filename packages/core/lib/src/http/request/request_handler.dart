import 'dart:convert' show htmlEscape;
import 'dart:io';
import 'package:vania/src/exception/database_exception.dart';
import 'package:vania/src/exception/query_exception.dart';
import 'package:vania/src/extensions/extensions.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/http/request/request_scope.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/http/session/session_gate.dart';
import 'package:vania/src/http/session/session_manager.dart';
import 'package:vania/src/route/middleware/csrf_middleware.dart';
import 'package:vania/src/view_engine/helper.dart';

import 'package:vania/src/config/http_cors.dart';
import 'package:vania/src/exception/internal_server_error.dart';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/exception/page_expired_exception.dart';
import 'package:vania/src/exception/not_found_exception.dart';
import 'package:vania/src/exception/unauthenticated.dart';
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

/// A single CSRF middleware instance, attached to every state-changing
/// route. `RouteData` is shared between requests, so per-request
/// instances must never be appended to it.
final CsrfMiddleware _csrfMiddleware = CsrfMiddleware();

class RequestHandler {
  Future handle(HttpRequest req) async {
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

    return runInRequestScope(req, () => _handleInScope(req));
  }

  Future<void> _handleInScope(HttpRequest req) async {
    final acceptHeader = req.headers.value('accept') ?? '';
    // `Accept` is client-controlled, so on its own it cannot decide whether
    // to mint and persist a session. An app that ships no views never wants
    // one regardless of what the client asks for.
    final bool isHtml = acceptHeader.contains('html') && sessionsEnabled();
    try {
      final RouteData? route = httpRouteHandler(req);
      if (route == null) return;

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

      Future<void> dispatch() async {
        await request.extractBody();

        if (isHtml) {
          final scope = currentRequestScope;
          if (scope != null) {
            scope.formData.addAll(request.all());
          }
        }

        await ControllerHandler().create(route: route, request: request);
      }

      if (pre.isEmpty) {
        await dispatch();
      } else {
        await middlewareHandler(pre, request, dispatch);
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
    } on BaseHttpResponseException catch (error) {
      if (error is NotFoundException && isHtml) {
        if (File('lib/resources/view/errors/404.html').existsSync()) {
          return view('errors/404').makeResponse(req.response);
        }
      }

      if (error is InternalServerError && isHtml) {
        if (File('lib/resources/view/errors/500.html').existsSync()) {
          return view('errors/500').makeResponse(req.response);
        }
      }

      if (error is PageExpiredException && isHtml) {
        if (File('lib/resources/view/errors/419.html').existsSync()) {
          return view('errors/419').makeResponse(req.response);
        }
      }

      if (error is Unauthenticated && isHtml) {
        return Response.redirect(error.message).makeResponse(req.response);
      }

      if (error is RedirectException && isHtml) {
        return Response.redirect(error.message).makeResponse(req.response);
      }

      await error.response(isHtml).makeResponse(req.response);
    } on InvalidArgumentException catch (e, stack) {
      await _fail(req, e, stack);
    } on DatabaseException catch (error, stack) {
      await _fail(req, error, stack);
    } on QueryException catch (error, stack) {
      await _fail(req, error, stack);
    } catch (e, stack) {
      await _fail(req, e, stack);
    }
  }

  /// Returns the effective pre-middleware list for [route] without
  /// mutating the cached RouteData. If CSRF is disabled or the route
  /// already has no middleware, the caller receives the route's own
  /// list back unchanged (no allocation).
  List<Middleware> _effectiveMiddleware(RouteData route) {
    if (!_csrfEnabled) return route.preMiddleware;

    final method = route.method;
    // CSRF only applies to state-changing methods. For everything else
    // the route's own list is fine.
    if (method != 'post' &&
        method != 'put' &&
        method != 'patch' &&
        method != 'delete') {
      return route.preMiddleware;
    }

    // Avoid double-inserting when the app already registered CSRF
    // explicitly.
    for (final m in route.preMiddleware) {
      if (identical(m, _csrfMiddleware) || m is CsrfMiddleware) {
        return route.preMiddleware;
      }
    }

    return <Middleware>[...route.preMiddleware, _csrfMiddleware];
  }

  /// Logs an internal failure with its stack trace and replies without
  /// leaking the underlying message unless APP_DEBUG is on. Mirrors
  /// `_fail` in ControllerHandler — same reasoning, different layer.
  Future<void> _fail(HttpRequest req, Object error, StackTrace stack) async {
    Logger.log('$error\n$stack', type: Logger.ERROR);
    final message = env<bool>('APP_DEBUG', false)
        ? error.toString()
        : 'Internal Server Error';
    await _response(req, message);
  }

  Future<void> _response(
    HttpRequest req,
    String message, {
    int statusCode = 500,
  }) async {
    if (req.headers.value('accept').toString().contains('html')) {
      await Response.html(
        htmlEscape.convert(message),
        statusCode: statusCode,
      ).makeResponse(req.response);
    } else {
      await Response.json({
        "message": message,
      }, statusCode).makeResponse(req.response);
    }
  }
}
