import 'dart:io';

import 'package:vania/src/config/http_cors.dart';
import 'package:vania/src/http/controller/controller_handler.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/route_handler.dart';
import 'package:vania/src/websocket/web_socket_handler.dart';
import 'package:vania/vania.dart';

Future httpRequestHandler(HttpRequest req) async {
  if (Config().get("websocket") && WebSocketTransformer.isUpgradeRequest(req)) {
    
      WebSocketHandler().handler(req);
    
  } else {
    try {
      HttpCros(req);
      Request request =
          await Request(request: req, route: httpRouteHandler(req)).call();
      RouteData? route = request.route;

      if (route == null) return;

      for (Middleware middleware in route.preMiddleware) {
        middleware.handle(request);
      }

      ControllerHandler(route: route, request: request).call();
    } on BaseHttpException catch (e) {
      e.call().makeResponse(req.response);
    }
  }
}
