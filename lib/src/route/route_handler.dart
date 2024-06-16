import 'dart:io';
import 'package:vania/src/enum/http_request_method.dart';
import 'package:vania/src/exception/not_found_exception.dart';
import 'package:vania/src/route/route_data.dart';
import 'package:vania/src/route/set_static_path.dart';
import 'package:vania/src/utils/functions.dart';
import 'package:vania/vania.dart';

RouteData? httpRouteHandler(HttpRequest req) {
  final route = _getMatchRoute(
    Uri.decodeComponent(req.uri.path.toLowerCase()),
    req.method,
    req.headers.value(HttpHeaders.hostHeader),
  );
  if (route == null) {
    if (req.method.toLowerCase() ==
        HttpRequestMethod.options.name.toLowerCase()) {
      req.response.close();
      return null;
    } else {
      final isFile = setStaticPath(req);
      if (isFile == null) {
        if (req.headers.value('accept') == "application/json") {
          throw NotFoundException(
            message: {'message': 'Not found'},
            responseType: ResponseType.json,
          );
        } else {
          throw NotFoundException();
        }
      }
    }
  }
  return route;
}

/// Exctract the domain from the url
String _extractDomain(String domain, String path) {
  String firstPart = domain.split('.').first.toLowerCase();
  final RegExp domainRegex = RegExp(r'\{[^}]*\}');
  bool containsPlaceholder = domainRegex.hasMatch(path);
  String domainUri = path;
  if (containsPlaceholder) {
    domainUri = path.replaceAll(domainRegex, firstPart).toLowerCase();
  }
  return domainUri;
}

/// Exctarct username from {username}
/// Or any string between {}
String? _extractDomainPlaceholder(String input) {
  final RegExp regex = RegExp(r'\{([^}]*)\}');
  final match = regex.firstMatch(input);
  if (match != null) {
    return match.group(1)!;
  } else {
    return null;
  }
}

RouteData? _getMatchRoute(String inputRoute, String method, String? domain) {
  String? domainParameter;
  String? domainPlaceholder;

  List<RouteData> routesList = Router().routes.where((route) {
    String routePath = route.path
        .trim()
        .replaceFirst(RegExp(r'^/'), '')
        .replaceFirst(RegExp(r'/$'), '');
    inputRoute = inputRoute
        .replaceFirst(RegExp(r'^/'), '')
        .replaceFirst(RegExp(r'/$'), '');

    if (route.prefix != null) {
      routePath =
          "${route.prefix!.replaceFirst(RegExp(r'^/'), '').replaceFirst(RegExp(r'/$'), '')}/$routePath";
    }

    if (routePath.split('/').length != inputRoute.split('/').length) {
      return false;
    }
    return route.method.toLowerCase() == method.toLowerCase() &&
        inputRoute.contains(
          routePath.replaceAll(RegExp(r'/\{[^}]*\}'), '').split('/').last,
        );
  }).toList();

  RouteData? matchRoute;
  for (RouteData route in routesList) {
    if (route.domain != null && domain != null) {
      String subDomain = _extractDomain(
        domain,
        route.domain!,
      );

      if (subDomain.toLowerCase() != domain.toLowerCase()) {
        matchRoute = null;
        break;
      }
      domainPlaceholder = _extractDomainPlaceholder(route.domain!);
      domainParameter = subDomain.split('.').first.toLowerCase();
    }

    route.path = sanitizeRoutePath(route.path.toLowerCase());
    inputRoute = sanitizeRoutePath(inputRoute.toLowerCase());
    String routePath = route.path.trim();

    /// When route is the same route exactly same route.
    /// route without params, eg. /api/example
    if (routePath == inputRoute.trim() && route.domain == null) {
      matchRoute = route;
      break;
    }

    if (route.prefix != null) {
      routePath = "${route.prefix}/$routePath";
    }

    /// when route have params
    /// eg. /api/admin/{adminId}
    Iterable<String> parameterNames = _getParameterNameFromRoute(route);
    Iterable<RegExpMatch> matches = _getPatternMatches(
      inputRoute,
      routePath,
    );

    if (matches.isNotEmpty) {
      final params = _getParameterAsMap(matches, parameterNames);
      if (route.paramTypes != null) {
        if (!checkParamType(params, route.paramTypes!)) {
          continue;
        }
      }

      if (route.regex != null) {
        if (!checkParamWithRegex(params, route.regex!)) {
          continue;
        }
      }

      matchRoute = route;
      matchRoute.params = params;
      if (domainPlaceholder != null && domainParameter != null) {
        matchRoute.params?.addAll({
          domainPlaceholder: domainParameter,
        });
      }
      break;
    }
  }
  return matchRoute;
}

bool checkParamWithRegex(
    Map<String, dynamic> param, Map<String, String> regexPatterns) {
  for (var key in regexPatterns.keys) {
    var value = param[key];
    var pattern = regexPatterns[key]!;
    if (value is String && !RegExp(pattern).hasMatch(value)) {
      return false;
    } else if (value is int && !RegExp(pattern).hasMatch(value.toString())) {
      return false;
    }
  }
  return true;
}

bool checkParamType(Map<String, dynamic> param, Map<String, Type> paramType) {
  bool isValidType(dynamic value, String type) {
    value = int.tryParse(value.toString()) ?? value;
    if (type == 'String') return value is String;
    if (type == 'int') return value is int;
    return false;
  }

  for (var key in paramType.keys) {
    if (!param.containsKey(key) ||
        !isValidType(param[key], paramType[key]!.toString())) {
      return false;
    }
  }
  return true;
}

/// Get parameter name from named route eg. /blog/{id}
/// eg ('id')
Iterable<String> _getParameterNameFromRoute(RouteData route) {
  return route.path
      .split('/')
      .where((String part) => part.startsWith('{') && part.endsWith('}'))
      .map((String part) => part.substring(1, part.length - 1));
}

/// Get  pattern matched routes from the list
Iterable<RegExpMatch> _getPatternMatches(
  String input,
  String route,
) {
  RegExp pattern = RegExp(
      '^${route.replaceAllMapped(RegExp(r'{[^/]+}'), (Match match) => '([^/]+)').replaceAll('/', '\\/')}\$');
  return pattern.allMatches(input);
}

/// Get  the param from the named route as Map response
/// eg {'id' : 1}
Map<String, dynamic> _getParameterAsMap(
  Iterable<RegExpMatch> matches,
  Iterable<String> parameterNames,
) {
  RegExpMatch match = matches.first;
  List<String?> parameterValues =
      match.groups(List<int>.generate(parameterNames.length, (int i) => i + 1));
  return Map<String, dynamic>.fromIterables(parameterNames, parameterValues);
}
