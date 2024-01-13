import 'package:vania/src/enum/http_request_method.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/vania.dart';

class Router {
  static final Router _singleton = Router._internal();
  factory Router() => _singleton;
  Router._internal();

  final List<RouteData> _routes = [];

  List<RouteData> get routes => _routes;

  static Router get(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.GET, path, action);
  }

  static Router post(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.POST, path, action);
  }

  static Router put(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.PUT, path, action);
  }

  static Router path(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.PATCH, path, action);
  }

  static Router delete(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.DELETE, path, action);
  }

  static Router options(String path, dynamic action) {
    return Router()._addRoute(HttpRequestMethod.OPTIONS, path, action);
  }

  Router _addRoute(HttpRequestMethod method, String path, dynamic action) {
    _routes.add(RouteData(
      method: method.name,
      path: path,
      action: action,
    ));
    return this;
  }

  Router middleware([List<Middleware>? middleware]) {
    if (middleware != null) {
      _routes.last.preMiddleware = middleware;
    }
    return this;
  }

  Router prefix([String? prifix]) {
    if (prifix != null) {
      String basePath = _routes.last.path;
      _routes.last.path =
          prifix.endsWith("/") ? "$prifix$basePath" : "$prifix/$basePath";
    }
    return this;
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
      : method = HttpRequestMethod.GET;
  const GroupRouter.post(this.path, this.action, {this.middleware})
      : method = HttpRequestMethod.POST;
  const GroupRouter.put(this.path, this.action, {this.middleware})
      : method = HttpRequestMethod.PUT;
  const GroupRouter.delete(this.path, this.action, {this.middleware})
      : method = HttpRequestMethod.DELETE;
  const GroupRouter.patch(this.path, this.action, {this.middleware})
      : method = HttpRequestMethod.PATCH;
}
