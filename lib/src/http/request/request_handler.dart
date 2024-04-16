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
  if (env<bool>('APP_WEBSOCKET') &&
      WebSocketTransformer.isUpgradeRequest(req)) {
    WebSocketHandler().handler(req);
  } else {
    try {
      /// Check if cors is enabled
      HttpCors(req);

      Request request =
          await Request(request: req, route: await httpRouteHandler(req))
              .call();
      RouteData? route = request.route;

      if (route == null) return;

      /// check if pre middleware exist and call it
      if (route.preMiddleware.isNotEmpty) {
       await middlewareHandler(route.preMiddleware,request);
      }

      /// Controller and method handler
      ControllerHandler(route: route, request: request).call();
    } on BaseHttpException catch (e) {
      e.call().makeResponse(req.response);
    } on InvalidArgumentException catch (e) {
      print(e.message);
    } catch (e) {
      print(e.toString());
    }
  }
}
