import 'package:vania/src/enum/http_request_method.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/websocket/web_socket_handler.dart';
import 'package:vania/src/websocket/websocket_event.dart';

import '../../vania.dart' show env;
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

  static final RegExp _requestVarRegex = RegExp(r'Closure: \(([^)]*)\) =>');
  static final RegExp _closureStartRegex = RegExp(r'Closure: \(');

  List<RouteData> get routes => List.unmodifiable(_routes);

  static String url(String name, [Map<String, dynamic>? params]) {
    RouteData routeData =
        Router()._routes.where((route) => route.name == name).first;

    if (params == null) {
      return '${env<String>('APP_URL')}/${routeData.path}';
    }

    final reg = RegExp(r'\{(\w+)\}');
    return routeData.path.replaceAllMapped(reg, (match) {
      final key = match.group(1)!;
      if (!params.containsKey(key)) {
        throw ArgumentError('Missing parameter: $key');
      }
      return '${env<String>('APP_URL')}/${params[key].toString()}';
    });
  }

  static void basePrefix([String? prefix]) {
    if (prefix == null) {
      Router()._prefix = null;
      return;
    }
    Router()._prefix =
        prefix.endsWith("/") ? prefix.substring(0, prefix.length - 1) : prefix;
  }

  bool _getRequestVar(String input) {
    if (!_closureStartRegex.hasMatch(input)) return false;

    final match = _requestVarRegex.firstMatch(input);
    if (match == null) return false;

    final params = match.group(1)!;
    final firstParam = params.split(',').firstOrNull;
    return firstParam == 'Request';
  }

  Router _addRouteInternal(
    HttpRequestMethod method,
    String path,
    Function action, {
    Map<String, Type>? paramTypes,
    Map<String, String>? regex,
  }) {
    final bool hasRequest = _getRequestVar(action.toString());

    if (!path.startsWith('/')) {
      path = '/$path';
    }

    final normalizedPath = _normalizePath(path);
    _routes.add(RouteData(
      method: method.name,
      path: normalizedPath,
      action: action,
      prefix: _prefix,
      paramTypes: paramTypes,
      regex: regex,
      hasRequest: hasRequest,
    ));
    return this;
  }

  String _normalizePath(String path) {
    return path.trim();
  }

  static Router _addRoute(
      HttpRequestMethod method, String path, Function action) {
    return Router()
        ._addRouteInternal(method, path, action)
        .middleware(Router()._groupMiddleware)
        .domain(Router()._groupDomain)
        .prefix(Router()._groupPrefix);
  }

  Router middleware([List<Middleware>? middleware]) {
    if (middleware != null && _routes.isNotEmpty) {
      _routes.last.preMiddleware = [
        ..._routes.last.preMiddleware,
        ...middleware
      ];
    }
    return this;
  }

  Router prefix([String? prefix]) {
    if (prefix != null && _routes.isNotEmpty) {
      final route = _routes.last;
      final basePath =
          route.path.startsWith('/') ? route.path.substring(1) : route.path;

      route.path =
          prefix.endsWith("/") ? "$prefix$basePath" : "$prefix/$basePath";
    }
    return this;
  }

  Router name([String? name]) {
    if (name != null && _routes.isNotEmpty) {
      _routes.last.name = name;
    }
    return this;
  }

  Router domain([String? domain]) {
    if (domain != null && _routes.isNotEmpty) {
      _routes.last.domain = domain;
    }
    return this;
  }

  Router whereInt(String paramName) {
    if (_routes.isNotEmpty) {
      _routes.last.paramTypes ??= {};
      _routes.last.paramTypes![paramName] = int;
    }
    return this;
  }

  Router whereString(String paramName) {
    if (_routes.isNotEmpty) {
      _routes.last.paramTypes ??= {};
      _routes.last.paramTypes![paramName] = String;
    }
    return this;
  }

  Router whereDouble(String paramName) {
    if (_routes.isNotEmpty) {
      _routes.last.paramTypes ??= {};
      _routes.last.paramTypes![paramName] = double;
    }
    return this;
  }

  Router whereBool(String paramName) {
    if (_routes.isNotEmpty) {
      _routes.last.paramTypes ??= {};
      _routes.last.paramTypes![paramName] = bool;
    }
    return this;
  }

  Router where(String paramName, String regex) {
    if (_routes.isNotEmpty) {
      _routes.last.regex ??= {};
      _routes.last.regex![paramName] = regex;
    }
    return this;
  }

  static Router get(String path, Function action) =>
      _addRoute(HttpRequestMethod.get, path, action);

  static Router post(String path, Function action) =>
      _addRoute(HttpRequestMethod.post, path, action);

  static Router put(String path, Function action) =>
      _addRoute(HttpRequestMethod.put, path, action);

  static Router patch(String path, Function action) =>
      _addRoute(HttpRequestMethod.patch, path, action);

  static Router delete(String path, Function action) =>
      _addRoute(HttpRequestMethod.delete, path, action);

  static Router options(String path, Function action) =>
      _addRoute(HttpRequestMethod.options, path, action);

  static Router purge(String path, Function action) =>
      _addRoute(HttpRequestMethod.purge, path, action);

  static Router copy(String path, Function action) =>
      _addRoute(HttpRequestMethod.copy, path, action);

  static Router link(String path, Function action) =>
      _addRoute(HttpRequestMethod.link, path, action);

  static Router unlink(String path, Function action) =>
      _addRoute(HttpRequestMethod.unlink, path, action);

  static Router lock(String path, Function action) =>
      _addRoute(HttpRequestMethod.lock, path, action);

  static Router unlock(String path, Function action) =>
      _addRoute(HttpRequestMethod.unlock, path, action);

  static Router propfind(String path, Function action) =>
      _addRoute(HttpRequestMethod.propfind, path, action);

  static Router any(String path, Function action) {
    final router = Router();

    final currentPrefix = router._prefix;

    for (HttpRequestMethod method in HttpRequestMethod.values) {
      final routeData = RouteData(
        method: method.name,
        path: router._normalizePath(path),
        action: action,
        prefix: currentPrefix,
        hasRequest: router._getRequestVar(action.toString()),
        preMiddleware: List.from(router._groupMiddleware),
        domain: router._groupDomain,
      );

      router._routes.add(routeData);
    }

    return router;
  }

  static void resource(
    String path,
    dynamic controller, {
    String? prefix,
    List<Middleware>? middleware,
    String? domain,
    String regex = r'\d+(.\d+)?',
  }) {
    Router.get(path, controller.index)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix);

    Router.get("$path/create", controller.create)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix);

    Router.post(path, controller.store)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix);

    Router.get("$path/{id}", controller.show)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix)
        .where('id', regex);

    Router.get("$path/{id}/edit", controller.edit)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix)
        .where('id', regex);

    Router.put("$path/{id}", controller.update)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix)
        .where('id', regex);

    Router.delete("$path/{id}", controller.destroy)
        .middleware(middleware)
        .domain(domain)
        .prefix(prefix)
        .where('id', regex);
  }

  static void websocket(
    String path,
    Function(WebSocketEvent) eventCallback, {
    List<WebSocketMiddleware>? middleware,
  }) {
    final currentPrefix = Router()._prefix;

    String fullPath = path;
    if (currentPrefix != null) {
      fullPath = currentPrefix.endsWith('/')
          ? "$currentPrefix$path"
          : "$currentPrefix/$path";
    }

    eventCallback(
        WebSocketHandler().websocketRoute(fullPath, middleware: middleware));
  }

  static void group(
    Function callback, {
    String? prefix = '',
    List<Middleware> middleware = const [],
    String? domain,
  }) {
    final router = Router();

    final previousDomain = router._groupDomain;
    final previousPrefix = router._groupPrefix;
    final previousMiddleware = List<Middleware>.from(router._groupMiddleware);

    router._groupDomain = domain ?? previousDomain;

    if (router._groupPrefix != null) {
      if (prefix != null) {
        if (!prefix.startsWith('/')) {
          prefix = '/$prefix';
        }
        router._groupPrefix = _joinPrefixes(router._groupPrefix!, prefix);
      }
    } else {
      if (prefix != null) {
        if (!prefix.startsWith('/')) {
          prefix = '/$prefix';
        }
      }
      router._groupPrefix = prefix;
    }

    if (middleware.isNotEmpty) {
      router._groupMiddleware.addAll(middleware);
    }
    callback();

    router._groupDomain = previousDomain;
    router._groupPrefix = previousPrefix;

    router._groupMiddleware
      ..clear()
      ..addAll(previousMiddleware);
  }

  static String _joinPrefixes(String basePrefix, String newPrefix) {
    final base = basePrefix.endsWith('/') ? basePrefix : '$basePrefix/';
    final prefix =
        newPrefix.startsWith('/') ? newPrefix.substring(1) : newPrefix;
    return '$base$prefix'.replaceAll(RegExp(r'//'), '/');
  }
}
