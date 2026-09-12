import 'package:vania/http/middleware.dart' show Middleware;
import 'package:vania/http/request.dart' show Request;
import 'package:vania/route.dart' show Router;

import '../config/graphql_config.dart';
import 'graphql_controller.dart';

class GraphQLRouteRegistrar {
  static final GraphQLRouteRegistrar _singleton =
      GraphQLRouteRegistrar._internal();

  factory GraphQLRouteRegistrar() => _singleton;

  GraphQLRouteRegistrar._internal();

  bool _registered = false;

  void register({
    GraphQLConfig? config,
    List<Middleware> middleware = const [],
  }) {
    final resolved = config ?? GraphQLConfig.fromApplication();
    if (!resolved.routeEnabled || _registered) return;

    final controller = VaniaGraphQLController(config: resolved);
    Router.any(
      resolved.endpoint,
      (Request request) => controller.handle(request),
    ).middleware(middleware).name('graphql');

    _registered = true;
  }

  void resetForTesting() {
    _registered = false;
  }
}
