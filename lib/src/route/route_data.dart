import 'package:vania/src/http/middleware/middleware.dart';

class RouteData {
  final String method;
  String path;
  final Function action;
  Map<String, dynamic>? params;
  List<Middleware> preMiddleware;
  String? domain;
  final bool? corsEnabled;
  final bool hasRequest;
  final String? prefix;
  String? name;
  Map<String, Type>? paramTypes;
  Map<String, String>? regex;

  RouteData({
    required this.method,
    required this.path,
    required this.action,
    this.corsEnabled,
    this.params,
    this.preMiddleware = const <Middleware>[],
    this.domain,
    this.prefix,
    this.hasRequest = false,
    this.paramTypes,
    this.name,
    this.regex,
  });
}
