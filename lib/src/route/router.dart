import 'package:vania/src/enum/http_request_method.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/websocket/web_socket_handler.dart';
import 'package:vania/vania.dart';

class Router {
  static final Router _singleton = Router._internal();
  factory Router() => _singleton;
  Router._internal();

  String? _prefix;
  String? _groupPrefix;
  String? _groupDomain;
  List<Middleware>? _groupMiddleware;

  static basePrefix(String prefix) {
    if (prefix.endsWith("/")) {
      prefix = prefix.substring(0, prefix.length - 1);
    }
    Router()._prefix = prefix;
  }

  final List<RouteData> _routes = [];

  List<RouteData> get routes => _routes;

  static Router get(String path, dynamic action) {
    return Router()
        ._addRoute(HttpRequestMethod.get, path, action)
        .middleware(Router()._groupMiddleware)
        .domain(Router()._groupDomain)
        .prefix(Router()._groupPrefix);
  }

  static Router post(String path, dynamic action) {
    return Router()
        ._addRoute(HttpRequestMethod.post, path, action)
        .middleware(Router()._groupMiddleware)
        .domain(Router()._groupDomain)
        .prefix(Router()._groupPrefix);
  }

  static Router put(String path, dynamic action) {
    return Router()
        ._addRoute(HttpRequestMethod.put, path, action)
        .middleware(Router()._groupMiddleware)
        .domain(Router()._groupDomain)
        .prefix(Router()._groupPrefix);
  }

  static Router patch(String path, dynamic action) {
    return Router()
        ._addRoute(HttpRequestMethod.patch, path, action)
        .middleware(Router()._groupMiddleware)
        .domain(Router()._groupDomain)
        .prefix(Router()._groupPrefix);
  }

  static Router delete(String path, dynamic action) {
    return Router()
        ._addRoute(HttpRequestMethod.delete, path, action)
        .middleware(Router()._groupMiddleware)
        .domain(Router()._groupDomain)
        .prefix(Router()._groupPrefix);
  }

  static Router options(String path, dynamic action) {
    return Router()
        ._addRoute(HttpRequestMethod.options, path, action)
        .middleware(Router()._groupMiddleware)
        .domain(Router()._groupDomain)
        .prefix(Router()._prefix);
  }

  Router _addRoute(HttpRequestMethod method, String path, dynamic action) {
    _routes.add(RouteData(
        method: method.name, path: path, action: action, prefix: _prefix));
    return this;
  }

  Router middleware([List<Middleware>? middleware]) {
    if (middleware != null) {
      if (_routes.last.preMiddleware.isNotEmpty) {
        middleware.addAll(_routes.last.preMiddleware);
      }
      _routes.last.preMiddleware = middleware;
    }
    return this;
  }

  Router prefix([String? prefix]) {
    if (prefix != null) {
      String basePath = _routes.last.path;
      _routes.last.path =
          prefix.endsWith("/") ? "$prefix$basePath" : "$prefix/$basePath";
    }

    return this;
  }

  Router domain([String? domain]) {
    if (domain != null) {
      _routes.last.domain = domain;
    }
    return this;
  }

  static void websocket(
    String path,
    Function(WebSocketEvent) eventCallBack, {
    List<WebSocketMiddleware>? middleware,
  }) {
    eventCallBack(WebSocketHandler().websocketRoute(
      path,
      middleware: middleware,
    ));
  }

  static void group(
    Function callBack, {
    String? prefix,
    List<Middleware>? middleware,
    String? domain,
  }) {
    Router()._groupPrefix = prefix;
    Router()._groupMiddleware = middleware;
    Router()._groupDomain = domain;
    callBack();
    Router()._groupPrefix = null;
    Router()._groupMiddleware = null;
    Router()._groupDomain = null;
  }
}
