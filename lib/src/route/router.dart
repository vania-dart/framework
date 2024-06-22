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

  final List<RouteData> _routes = [];

  List<RouteData> get routes => _routes;

  /// Sets the base prefix for all routes.
  static void basePrefix(String prefix) {
    Router()._prefix =
        prefix.endsWith("/") ? prefix.substring(0, prefix.length - 1) : prefix;
  }

  /// Adds a route internally.
  Router _addRouteInternal(
    HttpRequestMethod method,
    String path,
    Function action, {
    Map<String, Type>? paramTypes,
    Map<String, String>? regex,
  }) {
    bool hasRequest = _getRequestVar(action.toString());
    _routes.add(RouteData(
      method: method.name,
      path: path,
      action: action,
      prefix: _prefix,
      paramTypes: paramTypes,
      regex: regex,
      hasRequest: hasRequest,
    ));
    return this;
  }

  bool _getRequestVar(String input) {
    RegExp closureRegExp = RegExp(r'Closure: \(([^)]*)\) =>');
    Match? closureMatch = closureRegExp.firstMatch(input);
    if (closureMatch == null) return false;
    if (closureMatch.group(1)!.contains('Request') &&
        closureMatch.group(1)!.split(',')[0] == 'Request') {
      return true;
    } else {
      return false;
    }
  }

  /// Adds a route for the specified HTTP method, path, and action.
  static Router _addRoute(
      HttpRequestMethod method, String path, Function action) {
    return Router()
        ._addRouteInternal(method, path, action)
        .middleware(Router()._groupMiddleware)
        .domain(Router()._groupDomain)
        .prefix(Router()._groupPrefix);
  }

  /// Adds middleware to the last added route.
  Router middleware([List<Middleware>? middleware]) {
    if (middleware != null) {
      if (_routes.last.preMiddleware.isNotEmpty) {
        middleware.addAll(_routes.last.preMiddleware);
      }
      _routes.last.preMiddleware = middleware;
    }
    return this;
  }

  /// Adds a prefix to the last added route.
  Router prefix([String? prefix]) {
    if (prefix != null) {
      String basePath = _routes.last.path.startsWith('/')
          ? _routes.last.path.replaceFirst('/', '')
          : _routes.last.path;
      _routes.last.path =
          prefix.endsWith("/") ? "$prefix$basePath" : "$prefix/$basePath";
    }
    return this;
  }

  /// Adds a domain to the last added route.
  Router domain([String? domain]) {
    if (domain != null) {
      _routes.last.domain = domain;
    }
    return this;
  }

  /// Specifies a parameter as an integer.
  Router whereInt(String paramName) {
    _routes.last.paramTypes ??= {};
    _routes.last.paramTypes![paramName] = int;
    return this;
  }

  /// Specifies a parameter as a string.
  Router whereString(String paramName) {
    _routes.last.paramTypes ??= {};
    _routes.last.paramTypes![paramName] = String;
    return this;
  }

  /// Specifies a custom regular expression for a parameter.
  Router where(String paramName, String regex) {
    _routes.last.regex ??= {};
    _routes.last.regex![paramName] = regex;
    return this;
  }

  /// Adds a GET route.
  static Router get(String path, Function action) =>
      _addRoute(HttpRequestMethod.get, path, action);

  /// Adds a POST route.
  static Router post(String path, Function action) =>
      _addRoute(HttpRequestMethod.post, path, action);

  /// Adds a PUT route.
  static Router put(String path, Function action) =>
      _addRoute(HttpRequestMethod.put, path, action);

  /// Adds a PATCH route.
  static Router patch(String path, Function action) =>
      _addRoute(HttpRequestMethod.patch, path, action);

  /// Adds a DELETE route.
  static Router delete(String path, Function action) =>
      _addRoute(HttpRequestMethod.delete, path, action);

  /// Adds an OPTIONS route.
  static Router options(String path, Function action) =>
      _addRoute(HttpRequestMethod.options, path, action);

  /// Adds a PURGE route.
  static Router purge(String path, Function action) =>
      _addRoute(HttpRequestMethod.purge, path, action);

  /// Adds a COPY route.
  static Router copy(String path, Function action) =>
      _addRoute(HttpRequestMethod.copy, path, action);

  /// Adds a LINK route.
  static Router link(String path, Function action) =>
      _addRoute(HttpRequestMethod.link, path, action);

  /// Adds an UNLINK route.
  static Router unlink(String path, Function action) =>
      _addRoute(HttpRequestMethod.unlink, path, action);

  /// Adds a LOCK route.
  static Router lock(String path, Function action) =>
      _addRoute(HttpRequestMethod.lock, path, action);

  /// Adds an UNLOCK route.
  static Router unlock(String path, Function action) =>
      _addRoute(HttpRequestMethod.unlock, path, action);

  /// Adds a PROPFIND route.
  static Router propfind(String path, Function action) =>
      _addRoute(HttpRequestMethod.propfind, path, action);

  /// Adds a route that responds to any HTTP method.
  static Router any(String path, Function action) {
    Router router = Router();
    for (HttpRequestMethod method in HttpRequestMethod.values) {
      router
          ._addRouteInternal(method, path, action)
          .middleware(router._groupMiddleware)
          .domain(router._groupDomain)
          .prefix(router._groupPrefix);
    }
    return router;
  }

  /// Adds a set of resource routes.
  ///
  /// The action parameter should be an instance of a controller with methods:
  /// - index
  /// - create
  /// - store
  /// - show
  /// - edit
  /// - update
  /// - destroy
  static void resource(
    String path,
    dynamic action, {
    String? prefix,
    List<Middleware>? middleware,
    String? domain,
  }) {
    Router.get(path, action.index)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix);

    Router.get("$path/create", action.create)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix);

    Router.post(path, action.store)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix);

    Router.get("$path/{id}", action.show)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix)
        .whereInt('id');

    Router.get("$path/{id}/edit", action.edit)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix)
        .whereInt('id');

    Router.put("$path/{id}", action.update)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix)
        .whereInt('id');

    Router.delete("$path/{id}", action.destroy)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix)
        .whereInt('id');
  }

  /// Adds a websocket route.
  static void websocket(
    String path,
    Function(WebSocketEvent) eventCallBack, {
    List<WebSocketMiddleware>? middleware,
  }) {
    eventCallBack(
        WebSocketHandler().websocketRoute(path, middleware: middleware));
  }

  /// Groups a set of routes under a common prefix, middleware, and/or domain.
  static void group(
    Function callBack, {
    String? prefix,
    List<Middleware>? middleware,
    String? domain,
  }) {
    Router router = Router();
    router._groupPrefix = prefix;
    router._groupMiddleware = middleware;
    router._groupDomain = domain;
    callBack();
    router._groupPrefix = null;
    router._groupMiddleware = null;
    router._groupDomain = null;
  }
}
