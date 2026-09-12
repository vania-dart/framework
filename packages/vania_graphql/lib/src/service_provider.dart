import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:vania/http/middleware.dart' show Middleware;
import 'package:vania/service_provider.dart';

import 'config/graphql_config.dart';
import 'executor/vania_graphql_executor.dart';
import 'http/graphql_route_registrar.dart';
import 'schema/graphql_schema_registry.dart';
import 'websocket/graphql_ws_dispatcher.dart';

/// Wires GraphQL into a Vania application.
///
/// `register()` stores the schema in [GraphQLSchemaRegistry] so any code
/// that constructs a [VaniaGraphQLExecutor] later sees it. `boot()`
/// registers the HTTP route on [Router] and — when
/// `config.subscriptionsOverWebSocket` is set — installs a `graphql-ws`
/// handler on [WebSocketUpgradeDispatcher] that composes with any prior
/// override (e.g. `vania_websocket`).
class GraphQLServiceProvider extends ServiceProvider {
  const GraphQLServiceProvider({
    this.schema,
    this.config,
    this.customTypes = const [],
    this.middleware = const [],
    this.defaultFieldResolver,
  });

  final GraphQLSchema? schema;
  final GraphQLConfig? config;
  final List<GraphQLType> customTypes;
  final List<Middleware> middleware;
  final VaniaGraphQLDefaultFieldResolver? defaultFieldResolver;

  @override
  Future<void> register() async {
    final schema = this.schema;
    if (schema != null) {
      GraphQLSchemaRegistry().registerSchema(
        schema,
        customTypes: customTypes,
        defaultFieldResolver: defaultFieldResolver,
      );
    }
  }

  @override
  Future<void> boot() async {
    final resolved = config ?? GraphQLConfig.fromApplication();

    if (resolved.routeEnabled) {
      GraphQLRouteRegistrar().register(
        config: resolved,
        middleware: middleware,
      );
    }

    if (resolved.allowSubscriptions && resolved.subscriptionsOverWebSocket) {
      GraphQLWsDispatcher(resolved).install();
    }
  }
}
