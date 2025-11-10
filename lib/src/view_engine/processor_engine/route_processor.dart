import 'dart:convert';

import 'package:vania/src/exception/internal_server_error.dart';
import 'package:vania/src/route/router.dart';

import 'abs_processor.dart';

class RouteProcessor implements AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    final routePattern = RegExp(
      r"(\/?)\{\@\s*route\(\s*\'([^']+)\'(?:,\s*({[^}]+}))?\s*\)\s*\@\}",
      dotAll: true,
    );

    return content.replaceAllMapped(routePattern, (match) {
      String? slash = match.group(1);
      final routeName = match.group(2) ?? '';
      final jsonParams = match.group(3) ?? '';

      if (slash == null || slash.isEmpty) {
        slash = '/';
      }

      List filteredRoute = Router().routes
          .where((e) => e.name?.toLowerCase() == routeName.toLowerCase())
          .toList();
      if (filteredRoute.isEmpty) {
        throw InternalServerError(
          message: 'Route $routeName not found',
          code: 500,
        );
      }

      String path = filteredRoute.first.path;
      Map<String, dynamic> params = {};
      if (jsonParams.isNotEmpty) {
        try {
          params = jsonDecode(jsonParams);
        } catch (e) {
          params = {};
        }
      }

      if (params.isNotEmpty) {
        path = injectParams(path, params);
      }

      return "$slash$path";
    });
  }

  String injectParams(String template, Map<String, dynamic> params) {
    final placeholderPattern = RegExp(r'\{(\w+)\}');
    return template.replaceAllMapped(placeholderPattern, (match) {
      final key = match.group(1);
      final value = params[key];
      return value?.toString() ?? '';
    });
  }
}
