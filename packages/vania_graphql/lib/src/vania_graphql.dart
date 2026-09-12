import 'package:graphql_schema2/graphql_schema2.dart';

import 'config/graphql_config.dart';
import 'executor/vania_graphql_executor.dart';
import 'http/graphql_route_registrar.dart';
import 'request/graphql_request.dart';
import 'response/graphql_execution_result.dart';
import 'schema/graphql_schema_registry.dart';

class VaniaGraphQL {
  const VaniaGraphQL._();

  static void schema(
    GraphQLSchema schema, {
    Iterable<GraphQLType> customTypes = const [],
    VaniaGraphQLDefaultFieldResolver? defaultFieldResolver,
  }) {
    GraphQLSchemaRegistry().registerSchema(
      schema,
      customTypes: customTypes,
      defaultFieldResolver: defaultFieldResolver,
    );
  }

  static Future<VaniaGraphQLExecutionResult> execute(
    VaniaGraphQLRequest request, {
    GraphQLConfig? config,
  }) {
    return VaniaGraphQLExecutor(config: config).execute(request);
  }

  static void routes({GraphQLConfig? config}) {
    GraphQLRouteRegistrar().register(config: config);
  }

  static void resetForTesting() {
    GraphQLSchemaRegistry().reset();
    GraphQLRouteRegistrar().resetForTesting();
  }
}
