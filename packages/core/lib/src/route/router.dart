import 'package:vania/src/enum/http_request_method.dart';
import 'package:vania/src/http/middleware/middleware.dart';
import 'package:vania/src/route/route_data.dart';

import '../../env.dart' show env;

/// Route registration DSL.
class Router {
  static final Router _singleton = Router._internal();
  factory Router() => _singleton;
  Router._internal();

  String? _prefix;
  String? _groupPrefix;
  String? _groupDomain;
  final List<Middleware> _groupMiddleware = [];
  final List<RouteData> _routes = [];

  /// What the last registration added: one route, or one per method for
  /// [any]. Everything chained after it — middleware, constraints, a name —
  /// applies to all of these, so no method of an `any` route is left
  /// without the middleware meant to guard it.
  List<RouteData> _lastAdded = const [];

  static final RegExp _requestVarRegex = RegExp(r'Closure: \(([^)]*)\) =>');
  static final RegExp _closureStartRegex = RegExp(r'Closure: \(');

  List<RouteData> get routes => List.unmodifiable(_routes);

  static String url(String name, [Map<String, dynamic>? params]) {
    RouteData routeData = Router()._routes
        .where((route) => route.name == name)
        .first;

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
    Router()._prefix = prefix.endsWith("/")
        ? prefix.substring(0, prefix.length - 1)
        : prefix;
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
    final route = RouteData(
      method: method.name,
      path: normalizedPath,
      action: action,
      prefix: _prefix,
      paramTypes: paramTypes,
      regex: regex,
      hasRequest: hasRequest,
    );
    _routes.add(route);
    _lastAdded = [route];
    return this;
  }

  String _normalizePath(String path) {
    return path.trim();
  }

  static Router _addRoute(
    HttpRequestMethod method,
    String path,
    Function action,
  ) {
    return Router()
        ._addRouteInternal(method, path, action)
        .middleware(Router()._groupMiddleware)
        .domain(Router()._groupDomain)
        .prefix(Router()._groupPrefix);
  }

  Router middleware([List<Middleware>? middleware]) {
    if (middleware != null) {
      for (final route in _lastAdded) {
        route.preMiddleware = [...route.preMiddleware, ...middleware];
      }
    }
    return this;
  }

  Router prefix([String? prefix]) {
    if (prefix != null) {
      for (final route in _lastAdded) {
        final basePath = route.path.startsWith('/')
            ? route.path.substring(1)
            : route.path;

        route.path = prefix.endsWith("/")
            ? "$prefix$basePath"
            : "$prefix/$basePath";
      }
    }
    return this;
  }

  Router name([String? name]) {
    if (name != null) {
      for (final route in _lastAdded) {
        route.name = name;
      }
    }
    return this;
  }

  Router domain([String? domain]) {
    if (domain != null) {
      for (final route in _lastAdded) {
        route.domain = domain;
      }
    }
    return this;
  }

  /// The media types this `QUERY` route takes, such as
  /// `application/json`; `type/*` and `*/*` match a family or anything. A
  /// request with another type is answered with a 415, and the list is
  /// advertised in the `Accept-Query` header.
  Router acceptQuery(List<String> mediaTypes) {
    final accepted = [for (final type in mediaTypes) type.trim().toLowerCase()];
    for (final route in _lastAdded) {
      route.acceptQuery = accepted;
    }
    return this;
  }

  Router whereInt(String paramName) {
    for (final route in _lastAdded) {
      (route.paramTypes ??= {})[paramName] = int;
    }
    return this;
  }

  Router whereString(String paramName) {
    for (final route in _lastAdded) {
      (route.paramTypes ??= {})[paramName] = String;
    }
    return this;
  }

  Router whereDouble(String paramName) {
    for (final route in _lastAdded) {
      (route.paramTypes ??= {})[paramName] = double;
    }
    return this;
  }

  Router whereBool(String paramName) {
    for (final route in _lastAdded) {
      (route.paramTypes ??= {})[paramName] = bool;
    }
    return this;
  }

  Router where(String paramName, String regex) {
    for (final route in _lastAdded) {
      (route.regex ??= {})[paramName] = regex;
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

  /// A `QUERY` route (RFC 10008): a safe, idempotent read like `GET`, with
  /// the query in the request content instead of the URL — so it is not
  /// limited in length, and is less often written to logs on the way.
  ///
  /// The request must say what its content is with `Content-Type`; one
  /// that does not, or whose content does not parse as that type, is
  /// answered with a 400. Content the framework does not parse into
  /// fields, such as `application/sql`, is in `Request.rawBody`.
  static Router query(String path, Function action) =>
      _addRoute(HttpRequestMethod.query, path, action);

  /// A route for every HTTP method. Anything chained after it applies to
  /// all of them.
  static Router any(String path, Function action) {
    final router = Router();
    final added = <RouteData>[];
    for (final method in HttpRequestMethod.values) {
      _addRoute(method, path, action);
      added.addAll(router._lastAdded);
    }
    router._lastAdded = added;
    return router;
  }

  static void resource(
    String path,
    dynamic controller, {
    String? prefix,
    List<Middleware>? middleware,
    String? domain,
    String regex = r'\d+(\.\d+)?',
  }) {
    Router.get(
      path,
      controller.index,
    ).middleware(middleware).domain(domain).prefix(prefix);

    Router.get(
      "$path/create",
      controller.create,
    ).middleware(middleware).domain(domain).prefix(prefix);

    Router.post(
      path,
      controller.store,
    ).middleware(middleware).domain(domain).prefix(prefix);

    Router.get(
      "$path/{id}",
      controller.show,
    ).middleware(middleware).domain(domain).prefix(prefix).where('id', regex);

    Router.get(
      "$path/{id}/edit",
      controller.edit,
    ).middleware(middleware).domain(domain).prefix(prefix).where('id', regex);

    Router.put(
      "$path/{id}",
      controller.update,
    ).middleware(middleware).domain(domain).prefix(prefix).where('id', regex);

    Router.delete(
      "$path/{id}",
      controller.destroy,
    ).middleware(middleware).domain(domain).prefix(prefix).where('id', regex);
  }

  /// The routes of a JSON API resource: `index`, `store`, `show`,
  /// `update` (under both PUT and PATCH) and `destroy`.
  ///
  /// [resource] without `create` and `edit`, which only serve HTML forms,
  /// so the controller does not need them.
  static void apiResource(
    String path,
    dynamic controller, {
    String? prefix,
    List<Middleware>? middleware,
    String? domain,
    String regex = r'\d+(\.\d+)?',
  }) {
    Router.get(
      path,
      controller.index,
    ).middleware(middleware).domain(domain).prefix(prefix);

    Router.post(
      path,
      controller.store,
    ).middleware(middleware).domain(domain).prefix(prefix);

    Router.get(
      "$path/{id}",
      controller.show,
    ).middleware(middleware).domain(domain).prefix(prefix).where('id', regex);

    Router.put(
      "$path/{id}",
      controller.update,
    ).middleware(middleware).domain(domain).prefix(prefix).where('id', regex);

    Router.patch(
      "$path/{id}",
      controller.update,
    ).middleware(middleware).domain(domain).prefix(prefix).where('id', regex);

    Router.delete(
      "$path/{id}",
      controller.destroy,
    ).middleware(middleware).domain(domain).prefix(prefix).where('id', regex);
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
    try {
      callback();
    } finally {
      // Restored even when the callback fails, so the group's prefix and
      // middleware never reach routes registered after it.
      router._groupDomain = previousDomain;
      router._groupPrefix = previousPrefix;

      router._groupMiddleware
        ..clear()
        ..addAll(previousMiddleware);
    }
  }

  static String _joinPrefixes(String basePrefix, String newPrefix) {
    final base = basePrefix.endsWith('/') ? basePrefix : '$basePrefix/';
    final prefix = newPrefix.startsWith('/')
        ? newPrefix.substring(1)
        : newPrefix;
    return '$base$prefix'.replaceAll(RegExp(r'//'), '/');
  }
}
