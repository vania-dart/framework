import 'package:vania/src/enum/http_request_method.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/websocket/web_socket_handler.dart';
import 'package:vania/vania.dart';

import 'middleware/csrf_middleware.dart';

class Router {
  static final Router _singleton = Router._internal();
  factory Router() => _singleton;
  Router._internal();

  String? _prefix;
  String? _groupPrefix;
  String? _groupDomain;
  final List<Middleware> _groupMiddleware = [CsrfMiddleware()];

  final List<RouteData> _routes = [];

  List<RouteData> get routes => _routes;

  /// Sets the base prefix for all routes.
  static void basePrefix(String prefix) {
    Router()._prefix =
        prefix.endsWith("/") ? prefix.substring(0, prefix.length - 1) : prefix;
  }

  /// Internal method to add a route to the router. This method is used by the
  /// route macros like [get], [post], [put], [patch], [delete], etc.
  ///
  /// The [path] parameter is the path of the route. The [action] parameter is the
  /// function that will be called when the route is matched. The [paramTypes]
  /// parameter is a map of the parameter names to their types. The [regex]
  /// parameter is a map of the parameter names to their regular expressions.
  ///
  /// The [hasRequest] parameter is a boolean that indicates whether the route
  /// action has a request parameter. If it is true then the route action will
  /// receive a request object as a parameter.
  ///
  /// The method returns the router object so that you can chain it with other
  /// methods.
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

  /// Checks if the given input string is a closure that contains a
  /// [Request] object as its first parameter.
  ///
  /// The check is done by looking for the string 'Closure: (' and then
  /// extracting the parameter names and checking if the first one is
  /// 'Request'. If it is, then the method returns true. Otherwise, it
  /// returns false.
  ///
  /// The method is used by [_addRouteInternal] to determine if the route
  /// action has a request parameter. If it does, then the route action
  /// will receive a request object as a parameter.
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
      _routes.last.preMiddleware = [
        ..._routes.last.preMiddleware,
        ...middleware
      ];
    }
    return this;
  }

  /// Adds a prefix to the last added route.
  Router prefix([String? prefix]) {
    if (prefix != null) {
      String basePath = _routes.last.path.startsWith('/')
          ? _routes.last.path.substring(1)
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

  /// Groups a set of routes under the same prefix, middleware, and domain settings.
  ///
  /// The [callBack] function is executed within the context of the group, allowing
  /// routes added inside to inherit the specified [prefix], [middleware], and [domain].
  ///
  /// - [prefix]: An optional string to be added as a prefix to all routes within the group.
  /// - [middleware]: A list of middleware to be applied to all routes within the group.
  /// - [domain]: An optional domain that all routes within the group will respond to.
  static void group(
    Function callBack, {
    String? prefix,
    List<Middleware> middleware = const [],
    String? domain,
  }) {
    Router router = Router();
    router._groupDomain = domain;

    if (router._groupPrefix != null) {
      if (prefix != null) {
        router._groupPrefix =
            "${router._groupPrefix}/$prefix".replaceAll(r'//', '/');
      }
    } else {
      router._groupPrefix = prefix;
    }
    List<Middleware> previousGroupMiddleware =
        List.from(router._groupMiddleware);
    router._groupMiddleware.addAll(middleware);

    callBack();

    if (router._groupPrefix != null) {
      router._groupPrefix = router._groupPrefix!.replaceAll("$prefix", '');
    }

    router._groupMiddleware
      ..clear()
      ..addAll(previousGroupMiddleware);

    router._groupDomain = null;
  }
}
