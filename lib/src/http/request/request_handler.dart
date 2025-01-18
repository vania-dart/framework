import 'dart:io';
import 'package:vania/src/config/http_cors.dart';
import 'package:vania/src/exception/internal_server_error.dart';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/exception/page_expired_exception.dart';
import 'package:vania/src/exception/not_found_exception.dart';
import 'package:vania/src/exception/unauthenticated.dart';
import 'package:vania/src/http/controller/controller_handler.dart';
import 'package:vania/src/http/middleware/middleware_handler.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/route/route_history.dart';
import 'package:vania/src/view_engine/template_engine.dart';
import 'package:vania/src/websocket/web_socket_handler.dart';
import 'package:vania/vania.dart';

import '../session/session_manager.dart';

/// Handles HTTP requests, determining if the request is a WebSocket upgrade or
/// a standard HTTP request. If it's a WebSocket request, it delegates handling
/// to the WebSocketHandler; otherwise, it processes the request by checking
/// CORS, handling routes, invoking middleware, and executing the appropriate
/// controller action. The function also manages session initiation and logs
/// request details in debug mode.
///
/// Throws:
/// - [BaseHttpResponseException] if there is an issue with the HTTP response.
/// - [InvalidArgumentException] if an invalid argument is encountered.
Future httpRequestHandler(HttpRequest req) async {
  await SessionManager().sessionStart(req, req.response);

  /// Check the incoming request is web socket or not
  if (env<bool>('APP_WEBSOCKET', false) &&
      WebSocketTransformer.isUpgradeRequest(req)) {
    WebSocketHandler().handler(req);
  } else {
    DateTime startTime = DateTime.now();
    String requestUri = req.uri.path;
    String starteRequest = startTime.format();

    bool isHtml = req.headers.value('accept').toString().contains('html');

    try {
      /// Check if cors is enabled
      HttpCors(req);
      RouteData? route = httpRouteHandler(req);
      Request request = Request.from(request: req, route: route);
      await request.extractBody();
      if (route == null) return;

      RouteHistory().updateRouteHistory(req);

      if (isHtml) {
        TemplateEngine().formData.addAll(request.all());
      }

      /// check if pre middleware exist and call it
      if (route.preMiddleware.isNotEmpty) {
        await middlewareHandler(route.preMiddleware, request);
      }

      /// Controller and method handler
      ControllerHandler().create(
        route: route,
        request: request,
      );
    } on BaseHttpResponseException catch (error) {
      if (error is NotFoundException && isHtml) {
        if (File('lib/view/template/errors/404.html').existsSync()) {
          return view('errors/404').makeResponse(req.response);
        }
      }

      if (error is InternalServerError && isHtml) {
        if (File('lib/view/template/errors/500.html').existsSync()) {
          return view('errors/500').makeResponse(req.response);
        }
      }

      if (error is PageExpiredException && isHtml) {
        if (File('lib/view/template/errors/419.html').existsSync()) {
          return view('errors/419').makeResponse(req.response);
        }
      }

      if (error is Unauthenticated && isHtml) {
        return Response.redirect(error.message).makeResponse(req.response);
      }

      error
          .response(
            isHtml,
          )
          .makeResponse(req.response);
    } on InvalidArgumentException catch (e) {
      Logger.log(e.message, type: Logger.ERROR);
      _response(req, e.message);
    } catch (e) {
      Logger.log(e.toString(), type: Logger.ERROR);
      _response(req, e.toString());
    }

    if (env<bool>('APP_DEBUG')) {
      var endTime = DateTime.now();
      var duration = endTime.difference(startTime).inMilliseconds;
      var requestedPath = requestUri.isNotEmpty
          ? requestUri.padRight(118 - requestUri.length, '.')
          : ''.padRight(118, '.');
      print('$starteRequest $requestedPath ~ ${duration}ms');
    }
  }
}

void _response(req, message) {
  if (req.headers.value('accept').toString().contains('html')) {
    Response.html(message).makeResponse(req.response);
  } else {
    Response.json(
      {
        "message": message,
      },
      400,
    ).makeResponse(req.response);
  }
}
