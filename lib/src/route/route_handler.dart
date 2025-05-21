import 'dart:io';

import 'package:vania/src/enum/http_request_method.dart';
import 'package:vania/src/exception/not_found_exception.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/router.dart';
import 'package:vania/src/route/set_static_path.dart';
import 'package:vania/src/utils/functions.dart';

final Map<String, RegExp> _regexCache = {};
final _lookupCache = _LruCache<_LookupKey, RouteData?>(2000);
final Map<String, List<RouteData>> _staticRoutes = {};
final List<RouteData> _dynamicRoutes = [];

class _LookupKey {
  final String method;
  final String path;
  final String domain;

  _LookupKey(this.method, this.path, this.domain);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _LookupKey) return false;
    return method == other.method &&
        path == other.path &&
        domain == other.domain;
  }

  @override
  int get hashCode => Object.hash(method, path, domain);
}

class _LruCache<K, V> {
  final int maxSize;
  final _map = <K, V>{};

  _LruCache(this.maxSize);

  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    final value = _map.remove(key) as V;
    _map[key] = value;
    return value;
  }

  void put(K key, V value) {
    if (_map.containsKey(key)) {
      _map.remove(key);
    }
    _map[key] = value;
    if (_map.length > maxSize) {
      _map.remove(_map.keys.first);
    }
  }

  void clear() => _map.clear();

  bool contains(K key) => _map.containsKey(key);
}

void initializeRoutes() {
  final router = Router();
  for (var route in router.routes) {
    final method = route.method.toLowerCase();
    final normalizedPath =
        _normalizePath(_normalizePrefix(route.prefix) + route.path);
    route.regex?.forEach((param, pattern) {
      _regexCache.putIfAbsent(pattern, () => RegExp(pattern));
    });
    if (!normalizedPath.contains('{')) {
      _staticRoutes.putIfAbsent(method, () => []).add(route);
    } else {
      _dynamicRoutes.add(route);
    }
  }
}

/// Main HTTP request handler using LRU cache
RouteData? httpRouteHandler(HttpRequest req) {
  final method = req.method.toLowerCase();
  final rawPath = sanitizeRoutePath(req.uri.toString());
  final requestPath = Uri.decodeComponent(Uri.parse(rawPath).path);
  final domain = req.headers.value(HttpHeaders.hostHeader) ?? '';

  if (setStaticPath(req)) {
    return null;
  }

  final key = _LookupKey(method, requestPath, domain);
  final cached = _lookupCache.get(key);
  if (cached != null) {
    return cached;
  }

  final matchedRoute = _findMatchingRoute(requestPath, method, domain);
  _lookupCache.put(key, matchedRoute);

  if (matchedRoute == null) {
    return _handleNotFound(req, method);
  }
  return matchedRoute;
}

RouteData? _handleNotFound(HttpRequest req, String method) {
  if (method == HttpRequestMethod.options.name.toLowerCase()) {
    req.response
      ..headers.add('Content-Length', 0)
      ..close();
    return null;
  }

  throw NotFoundException(
    message: {'message': 'Not found'},
    responseType: ResponseType.json,
  );
}

RouteData? _findMatchingRoute(
    String requestPath, String method, String domain) {
  final staticList = _staticRoutes[method] ?? [];
  for (final route in staticList) {
    final fullPath =
        _normalizePath(_normalizePrefix(route.prefix) + route.path);
    if (fullPath == _normalizePath(requestPath) &&
        _domainMatches(domain, route.domain)) {
      return _applyDomainParams(route, domain);
    }
  }

  for (final route
      in _dynamicRoutes.where((r) => r.method.toLowerCase() == method)) {
    if (!_domainMatches(domain, route.domain)) continue;
    final result = _matchDynamic(requestPath, route, domain);
    if (result != null) return result;
  }

  return null;
}

bool _domainMatches(String requestDomain, String? routeDomain) {
  if (routeDomain == null) return true;
  final pattern = routeDomain.toLowerCase();

  if (!pattern.contains('{')) {
    return requestDomain.toLowerCase() == pattern;
  }

  final placeholder = RegExp(r'{([^}]+)}').firstMatch(pattern)!.group(1)!;
  final actual = requestDomain.split('.').first.toLowerCase();
  final expected = pattern.replaceAll('{$placeholder}', actual);
  return expected == requestDomain.toLowerCase();
}

RouteData _applyDomainParams(RouteData route, String domain) {
  final copy = RouteData(
    method: route.method,
    path: route.path,
    action: route.action,
    corsEnabled: route.corsEnabled,
    params: Map.from(route.params ?? {}),
    preMiddleware: List.from(route.preMiddleware),
    domain: route.domain,
    prefix: route.prefix,
    hasRequest: route.hasRequest,
    paramTypes: route.paramTypes != null ? Map.from(route.paramTypes!) : null,
    name: route.name,
    regex: route.regex != null ? Map.from(route.regex!) : null,
  );

  if (route.domain != null && route.domain!.contains('{')) {
    final placeholder =
        RegExp(r'{([^}]+)}').firstMatch(route.domain!)!.group(1)!;
    copy.params![placeholder] = domain.split('.').first;
  }

  return copy;
}

/// Matches dynamic (parameterized) routes and validates params
RouteData? _matchDynamic(String requestPath, RouteData route, String domain) {
  final patternPath =
      _normalizePath(_normalizePrefix(route.prefix) + route.path);
  final reqParts = _normalizePath(requestPath).split('/');
  final patternParts = patternPath.split('/');

  if (reqParts.length != patternParts.length) return null;

  final params = <String, dynamic>{};
  for (var i = 0; i < patternParts.length; i++) {
    final partPattern = patternParts[i];
    final partValue = reqParts[i];
    if (partPattern.startsWith('{') && partPattern.endsWith('}')) {
      final name = partPattern.substring(1, partPattern.length - 1);
      params[name] = partValue;
    } else if (partPattern != partValue) {
      return null;
    }
  }

  if (!_validateParams(params, route)) return null;
  final routed = _applyDomainParams(route, domain);
  routed.params = params;
  return routed;
}

/// Validates parameter types and regex constraints
bool _validateParams(Map<String, dynamic> params, RouteData route) {
  if (route.paramTypes != null) {
    for (final entry in route.paramTypes!.entries) {
      final name = entry.key;
      final type = entry.value;
      if (!params.containsKey(name)) return false;
      if (type == int) {
        final val = int.tryParse(params[name].toString());
        if (val == null) return false;
        params[name] = val;
      }
    }
  }

  if (route.regex != null) {
    for (final entry in route.regex!.entries) {
      final name = entry.key;
      final pattern = entry.value;
      final regex = _regexCache[pattern]!;
      if (!regex.hasMatch(params[name].toString())) return false;
    }
  }

  return true;
}

void clearRouteCaches() {
  _regexCache.clear();
  _lookupCache.clear();
  _staticRoutes.clear();
  _dynamicRoutes.clear();
}

/// Normalizes a route or request path: trims and removes extra slashes
String _normalizePath(String path) {
  return path
      .trim()
      .replaceAll('//', '/')
      .replaceAll(RegExp(r'/+\$'), '')
      .replaceAll(RegExp(r'^/'), '');
}

/// Normalizes the route prefix by ensuring leading slash and no trailing slash
String _normalizePrefix(String? prefix) {
  if (prefix == null || prefix.isEmpty) return '';
  final p = prefix.trim();
  return '/${p.replaceAll(RegExp(r'^/|/\$'), '')}';
}
