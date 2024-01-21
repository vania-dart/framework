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

      /// check if pre middleware exist and call it
      if (route.preMiddleware.isNotEmpty) {
        List<Middleware> middlewares = route.preMiddleware;
        for (int i = 0; i < middlewares.length - 1; i++) {
          middlewares[i].setNext(middlewares[i + 1]);
        }
        await middlewares.first.handle(request);
      }

      ControllerHandler(route: route, request: request).call();
    } on BaseHttpException catch (e) {
      e.call().makeResponse(req.response);
    }catch(e){
      print("catch ${e.toString()}");
    }
  }
}
