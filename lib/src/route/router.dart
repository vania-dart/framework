import 'package:vania/src/enum/http_request_method.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/websocket/web_socket_handler.dart';
import 'package:vania/vania.dart';

class Router {
  static final Router _singleton = Router._internal();
  factory Router() => _singleton;
  Router._internal();

  String? _prefix;

  static basePrefix(String prefix) {
    if (prefix.endsWith("/")) {
      prefix = prefix.substring(0, prefix.length - 1);
    }
    Router()._prefix = prefix;
  }

  final List<RouteData> _routes = [];

  List<RouteData> get routes => _routes;

  static Router get(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.get, path, action);
  }

  static Router post(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.post, path, action);
  }

  static Router put(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.put, path, action);
  }

  static Router patch(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.patch, path, action);
  }

  static Router delete(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.delete, path, action);
  }

  static Router options(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.options, path, action);
  }

  Router _addRoute(HttpRequestMethod method, String path, dynamic action) {
    _routes.add(RouteData(
        method: method.name, path: path, action: action, prefix: _prefix));
    return this;
  }

  Router middleware([List<Middleware>? middleware]) {
    if (middleware != null) {
      _routes.last.preMiddleware = middleware;
    }
    return this;
  }

  Router prefix([String? prefix]) {
    if (prefix != null) {
      String basePath = _routes.last.path;
      _routes.last.path =
          prifix.endsWith("/") ? "$prefix$basePath" : "$prefix/$basePath";
    }
    return this;
  }

  static void websocket(String path, Function(WebSocketEvent) eventCallBack) {
    WebSocketEvent event = WebSocketHandler();
    eventCallBack(event);
  }

  static void group(List<GroupRouter> routes,
      {String? prefix, List<Middleware>? middleware}) {
    for (GroupRouter route in routes) {
      List<Middleware> mid = route.middleware ?? [];
      mid.addAll(middleware ?? []);
      Router()
          ._addRoute(route.method, route.path, route.action)
          .prefix(prefix)
          .middleware(mid);
    }
  }
}

class GroupRouter {
  final String path;
  final dynamic action;
  final HttpRequestMethod method;
  final List<Middleware>? middleware;
  const GroupRouter.get(this.path, this.action, {this.middleware})
      : method = HttpRequestMethod.get;
  const GroupRouter.post(this.path, this.action, {this.middleware})
      : method = HttpRequestMethod.post;
  const GroupRouter.put(this.path, this.action, {this.middleware})
      : method = HttpRequestMethod.put;
  const GroupRouter.delete(this.path, this.action, {this.middleware})
      : method = HttpRequestMethod.delete;
  const GroupRouter.patch(this.path, this.action, {this.middleware})
      : method = HttpRequestMethod.patch;
  const GroupRouter.options(this.path, this.action, {this.middleware})
      : method = HttpRequestMethod.options;
}
