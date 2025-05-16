import 'dart:io';
import 'package:vania/src/enum/http_request_method.dart';
import 'package:vania/src/exception/not_found_exception.dart';
import 'package:vania/src/http/response/response.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/router.dart';
import 'package:vania/src/route/set_static_path.dart';
import 'package:vania/src/utils/functions.dart';

final Map<String, RegExp> _patternCache = {};

RouteData? httpRouteHandler(HttpRequest req) {
  final sanitizedPath = sanitizeRoutePath(req.uri.toString());
  final decodedPath = Uri.decodeComponent(Uri.parse(sanitizedPath).path);

  final route = _findMatchingRoute(
    decodedPath,
    req.method,
    req.headers.value(HttpHeaders.hostHeader),
  );

  if (route == null) {
    if (req.method.toLowerCase() ==
        HttpRequestMethod.options.name.toLowerCase()) {
      req.response.headers.add('Content-Length', 0);
      req.response.statusCode = HttpStatus.ok;
      req.response.close();
      return null;
    } else {
      final isFile = setStaticPath(req);
      if (!isFile) {
        throw NotFoundException(
          message: {'message': 'Not found'},
          responseType: ResponseType.json,
        );
      }
    }
  }
  return route;
}

String _extractDomain(String domain, String pattern) {
  final domainParts = domain.toLowerCase().split('.');
  final firstPart = domainParts.isNotEmpty ? domainParts.first : '';

  final RegExp domainRegex = RegExp(r'{[^}]*}');

  bool containsPlaceholder = domainRegex.hasMatch(pattern);

  if (!containsPlaceholder) return pattern;

  return pattern.replaceAll(domainRegex, firstPart).toLowerCase();
}

String? _extractDomainPlaceholder(String input) {
  final RegExp regex = RegExp(r'{([^}]*)}');
  final match = regex.firstMatch(input);
  return match?.group(1);
}

bool _isDomainMatch(String requestDomain, String routeDomain) {
  if (!routeDomain.contains('{')) {
    return requestDomain.toLowerCase() == routeDomain.toLowerCase();
  }

  String domainUri = _extractDomain(requestDomain, routeDomain);
  return domainUri.toLowerCase() == requestDomain.toLowerCase();
}

RouteData? _findMatchingRoute(
    String requestPath, String method, String? domain) {
  final routes = Router()
      .routes
      .where((r) => r.method.toLowerCase() == method.toLowerCase())
      .toList();

  final normalizedRequestPath = _normalizePath(requestPath);

  for (final route in routes) {
    String routePath = _normalizePath(route.path);
    if (route.prefix != null) {
      routePath = _normalizePath("${route.prefix}/$routePath");
    }

    if (route.domain != null && domain != null) {
      if (!_isDomainMatch(domain, route.domain!)) {
        continue;
      }
    }

    if (!routePath.contains("{")) {
      if (routePath == normalizedRequestPath) {
        final matchedRoute = _createRouteWithDomainParams(route, domain);
        return matchedRoute;
      }
      continue;
    }

    final pathMatch =
        _matchPathWithParams(normalizedRequestPath, routePath, route, domain);
    if (pathMatch != null) {
      return pathMatch;
    }
  }

  return null;
}

RouteData _createRouteWithDomainParams(RouteData route, String? domain) {
  final matchedRoute = RouteData(
    method: route.method,
    path: route.path,
    action: route.action,
    corsEnabled: route.corsEnabled,
    params: route.params != null ? Map.from(route.params!) : {},
    preMiddleware: List.from(route.preMiddleware),
    domain: route.domain,
    prefix: route.prefix,
    hasRequest: route.hasRequest,
    paramTypes: route.paramTypes != null ? Map.from(route.paramTypes!) : null,
    name: route.name,
    regex: route.regex != null ? Map.from(route.regex!) : null,
  );

  if (route.domain != null && domain != null && route.domain!.contains('{')) {
    final placeholder = _extractDomainPlaceholder(route.domain!);
    if (placeholder != null) {
      final domainParts = domain.split('.');
      if (domainParts.isNotEmpty) {
        matchedRoute.params ??= {};
        matchedRoute.params![placeholder] = domainParts.first;
      }
    }
  }

  return matchedRoute;
}

RouteData? _matchPathWithParams(
    String requestPath, String routePath, RouteData route, String? domain) {
  final routeParts = routePath.split('/');
  final requestParts = requestPath.split('/');

  if (routeParts.length != requestParts.length) {
    return null;
  }

  final params = <String, dynamic>{};
  for (int i = 0; i < routeParts.length; i++) {
    final routePart = routeParts[i];
    final requestPart = requestParts[i];

    if (routePart.startsWith('{') && routePart.endsWith('}')) {
      final paramName = routePart.substring(1, routePart.length - 1);
      params[paramName] = requestPart;
    } else if (routePart != requestPart) {
      return null;
    }
  }

  if (route.paramTypes != null || route.regex != null) {
    if (!_validateParams(params, route)) {
      return null;
    }
  }

  final matchedRoute = RouteData(
    method: route.method,
    path: route.path,
    action: route.action,
    corsEnabled: route.corsEnabled,
    params: params,
    preMiddleware: List.from(route.preMiddleware),
    domain: route.domain,
    prefix: route.prefix,
    hasRequest: route.hasRequest,
    paramTypes: route.paramTypes != null ? Map.from(route.paramTypes!) : null,
    name: route.name,
    regex: route.regex != null ? Map.from(route.regex!) : null,
  );

  if (route.domain != null && domain != null && route.domain!.contains('{')) {
    final placeholder = _extractDomainPlaceholder(route.domain!);
    if (placeholder != null) {
      final domainParts = domain.split('.');
      if (domainParts.isNotEmpty) {
        matchedRoute.params![placeholder] = domainParts.first;
      }
    }
  }

  return matchedRoute;
}

bool _validateParams(Map<String, dynamic> params, RouteData route) {
  if (route.paramTypes != null) {
    for (final entry in route.paramTypes!.entries) {
      final paramName = entry.key;
      final paramType = entry.value;

      if (!params.containsKey(paramName)) {
        return false;
      }

      final value = params[paramName];
      if (paramType == int) {
        final intValue = int.tryParse(value.toString());
        if (intValue == null) {
          return false;
        }
        params[paramName] = intValue;
      }
    }
  }

  if (route.regex != null) {
    for (final entry in route.regex!.entries) {
      final paramName = entry.key;
      final pattern = entry.value;

      if (!params.containsKey(paramName)) {
        return false;
      }

      final value = params[paramName].toString();
      final regex = _patternCache.putIfAbsent(pattern, () => RegExp(pattern));
      if (!regex.hasMatch(value)) {
        return false;
      }
    }
  }

  return true;
}

String _normalizePath(String path) {
  return path
      .trim()
      .replaceAll('//', '/')
      .replaceAll(RegExp(r'/$'), '')
      .replaceAll(RegExp(r'^/'), '');
}
