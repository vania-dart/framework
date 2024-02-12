


import 'package:vania/vania.dart';

class RouteData {
  final String method;
  String path;
  final dynamic action;
  Map<String, dynamic>? params;
  List<Middleware> preMiddleware;
  final String? domain;
  final bool? corsEnabled;
  final String? prefix;

  RouteData({
    required this.method,
    required this.path,
    required this.action,
    this.corsEnabled,
    this.params,
    this.preMiddleware = const <Middleware>[],
    this.domain,
    this.prefix,
  });
}
