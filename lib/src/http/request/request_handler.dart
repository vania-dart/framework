import 'dart:io';
import 'package:vania/src/config/http_cors.dart';
import 'package:vania/src/exception/invalid_argument_exception.dart';
import 'package:vania/src/http/controller/controller_handler.dart';
import 'package:vania/src/http/middleware/middleware_handler.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/websocket/web_socket_handler.dart';
import 'package:vania/vania.dart';

Future httpRequestHandler(HttpRequest req) async {
  /// Check the incoming request is web socket or not
  if (env<bool>('APP_WEBSOCKET', false) &&
      WebSocketTransformer.isUpgradeRequest(req)) {
    WebSocketHandler().handler(req);
  } else {
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
            req.headers.value('accept') == "application/json",
          )
          .makeResponse(req.response);
    } on InvalidArgumentException catch (e) {
      Logger.log(e.message, type: Logger.ERROR);
      _response(req, e.message);
    } catch (e) {
      Logger.log(e.toString(), type: Logger.ERROR);
      _response(req, e.toString());
    }
  }
}

void _response(req, message) {
  if (req.headers.value('accept') == "application/json") {
    Response.json(
      {
        "message": message,
      },
      400,
    ).makeResponse(req.response);
  } else {
    Response.html(message).makeResponse(req.response);
  }
}
