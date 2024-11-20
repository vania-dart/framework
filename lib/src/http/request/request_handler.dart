import 'dart:io';
import 'package:vaniaFramework/src/config/http_cors.dart';
import 'package:vaniaFramework/src/exception/invalid_argument_exception.dart';
import 'package:vaniaFramework/src/http/controller/controller_handler.dart';
import 'package:vaniaFramework/src/http/middleware/middleware_handler.dart';
import 'package:vaniaFramework/src/route/route_data.dart';
import 'package:vaniaFramework/src/route/route_handler.dart';
import 'package:vaniaFramework/src/websocket/web_socket_handler.dart';
import 'package:vaniaFramework/vania_framework.dart';
Future httpRequestHandler(HttpRequest req) async {
  /// Check the incoming request is web socket or not
  if (env<bool>('APP_WEBSOCKET', false) &&
      WebSocketTransformer.isUpgradeRequest(req)) {
    WebSocketHandler().handler(req);
  } else {
    DateTime startTime = DateTime.now();
    String requestUri = req.uri.path;
    String starteRequest = startTime.format();

    try {
      /// Check if cors is enabled
      HttpCors(req);
      RouteData? route = httpRouteHandler(req);
      Request request = Request.from(request: req, route: route);
      await request.extractBody();
      if (route == null) return;

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
      error
          .response(
            req.headers.value('accept').toString().contains('html'),
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
