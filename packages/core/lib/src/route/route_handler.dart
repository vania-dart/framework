import 'dart:io';

import 'package:vania/src/enum/http_request_method.dart';
import 'package:vania/src/exception/not_found_exception.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/router.dart';

final RegExp _multiSlash = RegExp(r'/+');
final RegExp _domainPlaceholder = RegExp(r'{([^}]+)}');

final Map<String, RegExp> _regexCache = {};

/// Static routes by method and path. A path can have several routes, one
/// per domain: those for a domain first, then the one for any host.
final Map<String, Map<String, List<RouteData>>> _staticPathIndex = {};

final Map<String, Map<int, _DynamicBucket>> _dynamicByMethodAndSegments = {};

final Set<String> _methodsWithDynamics = <String>{};

/// True when at least one registered route is domain-scoped. Only then
/// does matching depend on the Host header, so only then is it read.
bool _hasDomainRoutes = false;

/// The dynamic routes of one method with the same number of segments.
class _DynamicBucket {
  /// In registration order, which decides between routes that both match.
  final List<_CompiledDynamicRoute> all = <_CompiledDynamicRoute>[];

  /// For each literal first segment, the routes a path starting with it
  /// can match: those naming that segment and those with a parameter
  /// there, still in registration order. Most lookups then try one or two
  /// routes rather than every route of the same length.
  Map<String, List<_CompiledDynamicRoute>> _byFirst = const {};

  /// The routes for a path whose first segment no route names.
  List<_CompiledDynamicRoute> _paramFirst = const [];

  void index() {
    _paramFirst = [
      for (final r in all)
        if (r.isParam[0]) r,
    ];
    _byFirst = {
      for (final r in all)
        if (!r.isParam[0])
          r.patternParts[0]: [
            for (final c in all)
              if (c.isParam[0] || c.patternParts[0] == r.patternParts[0]) c,
          ],
    };
  }

  List<_CompiledDynamicRoute> candidatesFor(String firstSegment) =>
      _byFirst[firstSegment] ?? _paramFirst;
}

class _CompiledDynamicRoute {
  final RouteData route;

  final List<String> patternParts;

  final List<bool> isParam;

  final List<String?> paramNames;

  _CompiledDynamicRoute(this.route, this.patternParts)
    : isParam = List<bool>.generate(
        patternParts.length,
        (i) => patternParts[i].startsWith('{') && patternParts[i].endsWith('}'),
      ),
      paramNames = List<String?>.generate(
        patternParts.length,
        (i) =>
            (patternParts[i].startsWith('{') && patternParts[i].endsWith('}'))
            ? patternParts[i].substring(1, patternParts[i].length - 1)
            : null,
      );
}

final String _optionsMethodName = HttpRequestMethod.options.name.toLowerCase();

void initializeRoutes() {
  final router = Router();
  for (final route in router.routes) {
    final method = route.method.toLowerCase();
    final normalized = _normalizeRoutePath(
      _normalizePrefix(route.prefix) + route.path,
    );

    route.regex?.forEach((param, pattern) {
      // The whole segment has to match, not just some part of it:
      // `where('id', r'\d+')` must turn away `abc123`.
      _regexCache.putIfAbsent(pattern, () => RegExp('^(?:$pattern)\$'));
    });

    if (route.domain != null) {
      _hasDomainRoutes = true;
      if (route.domain!.contains('{')) {
        _regexCache.putIfAbsent(route.domain!, () => _domainPlaceholder);
      }
    }

    if (!normalized.contains('{')) {
      final routes =
          (_staticPathIndex[method] ??=
                  <String, List<RouteData>>{})[normalized] ??=
              <RouteData>[];
      // Registered again for the same domain, the path keeps its latest
      // route; for another domain, the two stand side by side.
      routes.removeWhere((r) => r.domain == route.domain);
      if (route.domain == null) {
        routes.add(route);
      } else {
        routes.insert(0, route);
      }
    } else {
      final parts = normalized.split('/');
      _methodsWithDynamics.add(method);
      final byLen = (_dynamicByMethodAndSegments[method] ??=
          <int, _DynamicBucket>{});
      (byLen[parts.length] ??= _DynamicBucket()).all.add(
        _CompiledDynamicRoute(route, parts),
      );
    }
  }

  for (final byLen in _dynamicByMethodAndSegments.values) {
    for (final bucket in byLen.values) {
      bucket.index();
    }
  }
}

/// Returns the route [req] resolves to, or null when none matches.
///
/// No match is an ordinary outcome — scanners alone produce plenty — so it
/// is reported by value: throwing costs more than the whole lookup.
RouteData? matchRoute(HttpRequest req) {
  final requestPath = _decodePath(_stripSlashes(req.uri.path));
  if (requestPath == null) return null;
  final domain = _hasDomainRoutes
      ? req.headers.value(HttpHeaders.hostHeader) ?? ''
      : '';
  final method = _lowerMethod(req.method);
  return _findMatchingRoute(requestPath, method, domain) ??
      // HEAD is GET without the body (RFC 9110 §9.3.2), so the GET route
      // answers it; dart:io leaves the body off by itself.
      (method == 'head'
          ? _findMatchingRoute(requestPath, 'get', domain)
          : null);
}

/// The routes [req]'s path has, one per method that has one, in
/// [HttpRequestMethod] order. For answering `OPTIONS` with what the path
/// allows.
List<RouteData> routesForPath(HttpRequest req) {
  final requestPath = _decodePath(_stripSlashes(req.uri.path));
  if (requestPath == null) return const [];
  final domain = _hasDomainRoutes
      ? req.headers.value(HttpHeaders.hostHeader) ?? ''
      : '';
  return [
    for (final method in HttpRequestMethod.values)
      ?_findMatchingRoute(requestPath, method.name, domain),
  ];
}

/// Like [matchRoute], but answers an unmatched `OPTIONS` request itself
/// (returning null) and throws [routeNotFound] for anything else.
RouteData? httpRouteHandler(HttpRequest req) =>
    matchRoute(req) ?? _handleNotFound(req, _lowerMethod(req.method));

/// The error a request that matches no route is answered with.
NotFoundException routeNotFound() => NotFoundException(
  message: {'message': 'Not found'},
  responseType: ResponseType.json,
);

RouteData? _handleNotFound(HttpRequest req, String method) {
  if (method == _optionsMethodName) {
    req.response
      ..headers.add('Content-Length', 0)
      ..close();
    return null;
  }

  throw routeNotFound();
}

/// A request path ready for matching: [key] for the static index, and the
/// [segments] for dynamic routes — null when splitting [key] gives them.
typedef _RequestPath = ({String key, List<String>? segments});

/// [rawPath] as text: routes are written as text, while a request path
/// arrives percent-encoded, so `/مقالات/7` comes in as `%D9%85…/7`.
///
/// Segments are decoded one by one, after splitting, so an encoded `/`
/// stays inside its segment rather than starting a new one. A path with
/// no escapes — nearly all of them — is used as it is. Null when an
/// escape is malformed: such a path names no route.
_RequestPath? _decodePath(String rawPath) {
  if (!rawPath.contains('%')) return (key: rawPath, segments: null);
  try {
    final segments = [
      for (final segment in _splitPath(rawPath))
        segment.contains('%') ? Uri.decodeComponent(segment) : segment,
    ];
    // Joined back up, a segment holding an encoded `/` would read as two,
    // and `a%2Fb` would find the static route `a/b`. Such a path is looked
    // up in the static index as it came.
    final key = segments.any((s) => s.contains('/'))
        ? rawPath
        : segments.join('/');
    return (key: key, segments: segments);
  } catch (_) {
    return null;
  }
}

RouteData? _findMatchingRoute(
  _RequestPath requestPath,
  String method,
  String domain,
) {
  final hits = _staticPathIndex[method]?[requestPath.key];
  if (hits != null) {
    for (final hit in hits) {
      if (!_domainMatches(domain, hit.domain)) continue;
      if (hit.domain != null && hit.domain!.contains('{')) {
        return _applyDomainParams(hit, domain);
      }
      return hit;
    }
  }

  if (_methodsWithDynamics.contains(method)) {
    final byLen = _dynamicByMethodAndSegments[method];
    if (byLen != null) {
      final reqParts = requestPath.segments ?? _splitPath(requestPath.key);
      final bucket = byLen[reqParts.length];
      if (bucket != null) {
        for (final compiled in bucket.candidatesFor(reqParts[0])) {
          if (!_domainMatches(domain, compiled.route.domain)) continue;
          final result = _matchDynamic(reqParts, compiled, domain);
          if (result != null) return result;
        }
      }
    }
  }

  return null;
}

List<String> _splitPath(String path) {
  if (path.isEmpty) return const <String>[''];
  var count = 1;
  for (var i = 0; i < path.length; i++) {
    if (path.codeUnitAt(i) == 0x2F) count++;
  }
  final out = List<String>.filled(count, '', growable: false);
  var idx = 0;
  var start = 0;
  for (var i = 0; i < path.length; i++) {
    if (path.codeUnitAt(i) == 0x2F) {
      out[idx++] = path.substring(start, i);
      start = i + 1;
    }
  }
  out[idx] = path.substring(start);
  return out;
}

bool _domainMatches(String requestDomain, String? routeDomain) {
  if (routeDomain == null) return true;
  final pattern = routeDomain.toLowerCase();

  if (!pattern.contains('{')) {
    return requestDomain.toLowerCase() == pattern;
  }

  final placeholder = _domainPlaceholder.firstMatch(pattern)!.group(1)!;
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
    params: route.params != null ? Map.of(route.params!) : <String, dynamic>{},
    preMiddleware: route.preMiddleware,
    domain: route.domain,
    prefix: route.prefix,
    hasRequest: route.hasRequest,
    paramTypes: route.paramTypes,
    name: route.name,
    regex: route.regex,
    acceptQuery: route.acceptQuery,
  );

  if (route.domain != null && route.domain!.contains('{')) {
    final placeholder = _domainPlaceholder.firstMatch(route.domain!)!.group(1)!;
    copy.params![placeholder] = domain.split('.').first;
  }

  return copy;
}

/// Matches dynamic (parameterized) routes and validates params.
RouteData? _matchDynamic(
  List<String> reqParts,
  _CompiledDynamicRoute compiled,
  String domain,
) {
  final patternParts = compiled.patternParts;

  for (var i = 0; i < patternParts.length; i++) {
    if (!compiled.isParam[i] && patternParts[i] != reqParts[i]) {
      return null;
    }
  }

  final route = compiled.route;
  final hasParamTypes = route.paramTypes != null;
  final hasRegex = route.regex != null;

  final params = <String, dynamic>{};
  for (var i = 0; i < patternParts.length; i++) {
    if (compiled.isParam[i]) {
      params[compiled.paramNames[i]!] = reqParts[i];
    }
  }
  if (hasParamTypes && !_applyParamTypes(params, route)) return null;
  if (hasRegex && !_applyRegex(params, route)) return null;

  final needsDomainRewrite =
      route.domain != null && route.domain!.contains('{');
  if (!needsDomainRewrite) {
    return RouteData(
      method: route.method,
      path: route.path,
      action: route.action,
      corsEnabled: route.corsEnabled,
      params: params,
      preMiddleware: route.preMiddleware,
      domain: route.domain,
      prefix: route.prefix,
      hasRequest: route.hasRequest,
      paramTypes: route.paramTypes,
      name: route.name,
      regex: route.regex,
      acceptQuery: route.acceptQuery,
    );
  }

  final routed = _applyDomainParams(route, domain);
  routed.params = params;
  if (routed.params!.isEmpty) routed.params = params;
  return routed;
}

bool _applyParamTypes(Map<String, dynamic> params, RouteData route) {
  for (final entry in route.paramTypes!.entries) {
    final name = entry.key;
    final type = entry.value;
    if (!params.containsKey(name)) return false;
    final raw = params[name].toString();
    // A declared type is checked and applied here, once: the controller
    // receives the value as is, and a mismatch is no match at all.
    final Object? typed = type == int
        ? int.tryParse(raw)
        : type == double
        ? double.tryParse(raw)
        : type == bool
        ? _parseBool(raw)
        : raw;
    if (typed == null) return false;
    params[name] = typed;
  }
  return true;
}

bool? _parseBool(String raw) => switch (raw.toLowerCase()) {
  'true' => true,
  'false' => false,
  _ => null,
};

bool _applyRegex(Map<String, dynamic> params, RouteData route) {
  for (final entry in route.regex!.entries) {
    final regex = _regexCache[entry.value]!;
    if (!regex.hasMatch(params[entry.key].toString())) return false;
  }
  return true;
}

void clearRouteCaches() {
  _regexCache.clear();
  _staticPathIndex.clear();
  _dynamicByMethodAndSegments.clear();
  _methodsWithDynamics.clear();
  _hasDomainRoutes = false;
}

String _normalizeRoutePath(String path) {
  final trimmed = path.trim();
  final collapsed = trimmed.replaceAll(_multiSlash, '/');
  return _stripSlashes(collapsed);
}

/// Normalizes the route prefix by ensuring leading slash and no trailing slash.
String _normalizePrefix(String? prefix) {
  if (prefix == null || prefix.isEmpty) return '';
  final p = prefix.trim();
  final stripped = _stripSlashes(p);
  return '/$stripped';
}

String _stripSlashes(String path) {
  if (path.isEmpty) return path;
  var start = 0;
  var end = path.length;
  while (start < end && path.codeUnitAt(start) == 0x2F) {
    start++;
  }
  while (end > start && path.codeUnitAt(end - 1) == 0x2F) {
    end--;
  }
  if (start == 0 && end == path.length) return path;
  return path.substring(start, end);
}

String _lowerMethod(String m) {
  switch (m) {
    case 'GET':
      return 'get';
    case 'POST':
      return 'post';
    case 'PUT':
      return 'put';
    case 'DELETE':
      return 'delete';
    case 'PATCH':
      return 'patch';
    case 'OPTIONS':
      return 'options';
    case 'HEAD':
      return 'head';
    case 'QUERY':
      return 'query';
    case 'get':
    case 'post':
    case 'put':
    case 'delete':
    case 'patch':
    case 'options':
    case 'head':
    case 'query':
      return m;
    default:
      return m.toLowerCase();
  }
}
