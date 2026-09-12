import 'package:graphql_schema2/graphql_schema2.dart';
import 'package:graphql_server2/graphql_server2.dart';
import 'package:vania/foundation.dart' show Logger;

import '../config/graphql_config.dart';
import 'graphql_depth_limiter.dart';
import '../context/graphql_context.dart';
import '../errors/graphql_error_formatter.dart';
import '../request/graphql_request.dart';
import '../response/graphql_execution_result.dart';
import '../schema/graphql_schema_registry.dart';

class VaniaGraphQLExecutor {
  VaniaGraphQLExecutor({
    GraphQLSchema? schema,
    GraphQLConfig? config,
    Iterable<GraphQLType> customTypes = const [],
    VaniaGraphQLDefaultFieldResolver? defaultFieldResolver,
  }) : config = config ?? GraphQLConfig.fromApplication(),
       _schema = schema ?? GraphQLSchemaRegistry().schema,
       _customTypes = List<GraphQLType>.from(
         customTypes.isEmpty
             ? GraphQLSchemaRegistry().customTypes
             : customTypes,
       ),
       _defaultFieldResolver =
           defaultFieldResolver ?? GraphQLSchemaRegistry().defaultFieldResolver;

  final GraphQLConfig config;
  final GraphQLSchema _schema;
  final List<GraphQLType> _customTypes;
  final VaniaGraphQLDefaultFieldResolver? _defaultFieldResolver;

  Future<VaniaGraphQLExecutionResult> execute(
    VaniaGraphQLRequest request,
  ) async {
    final validationError = _validate(request);
    if (validationError != null) {
      return VaniaGraphQLExecutionResult(
        payload: validationError.toJson(),
        statusCode: 400,
      );
    }

    final formatter = VaniaGraphQLErrorFormatter(
      exposeExceptionDetails: config.exposeExceptionDetails,
    );

    try {
      final graphQL = GraphQL(
        _schema,
        introspect: config.introspectionEnabled,
        customTypes: _customTypes,
        defaultFieldResolver: _defaultFieldResolver,
      );

      final future = graphQL.parseAndExecute(
        request.query,
        operationName: request.operationName,
        variableValues: request.variables,
        initialValue: request.rootValue ?? request.context,
        globalVariables: _globalVariables(request),
      );

      final result = await _withTimeout(future);
      if (result is Stream) {
        if (!config.allowSubscriptions) {
          return const VaniaGraphQLExecutionResult(
            payload: {
              'errors': [
                {'message': 'GraphQL subscriptions are disabled.'},
              ],
            },
            statusCode: 400,
          );
        }

        return VaniaGraphQLExecutionResult(
          stream: result.map(
            (event) => Map<String, dynamic>.from(event as Map),
          ),
        );
      }

      return VaniaGraphQLExecutionResult(
        payload: {'data': Map<String, dynamic>.from(result as Map)},
      );
    } on GraphQLException catch (error) {
      return VaniaGraphQLExecutionResult(
        payload: formatter.fromGraphQLException(error),
        statusCode: config.errorStatusCode,
      );
    } catch (error, stackTrace) {
      Logger.log('$error\n$stackTrace', type: Logger.ERROR);
      return VaniaGraphQLExecutionResult(
        payload: formatter.fromException(error),
        statusCode: 500,
      );
    }
  }

  VaniaGraphQLRequestException? _validate(VaniaGraphQLRequest request) {
    final maxLength = config.maxQueryLength;
    if (maxLength != null && request.query.length > maxLength) {
      return VaniaGraphQLRequestException(
        'GraphQL query exceeds the configured max length of $maxLength.',
      );
    }

    // Depth is checked before execution because a length cap does not
    // bound cost: a deeply nested query against a cyclic schema stays
    // small on the wire and still fans out into unbounded resolver work.
    final maxDepth = config.maxQueryDepth;
    if (maxDepth != null) {
      final depth = GraphQLDepthLimiter.depthOf(request.query);
      // A null depth means the document didn't parse — leave that to the
      // executor, which reports it as a proper GraphQL syntax error.
      if (depth != null && depth > maxDepth) {
        return VaniaGraphQLRequestException(
          'GraphQL query is nested $depth levels deep, exceeding the '
          'configured maximum of $maxDepth.',
        );
      }
    }

    return null;
  }

  Map<String, dynamic> _globalVariables(VaniaGraphQLRequest request) {
    final context = request.context ?? VaniaGraphQLContext();
    return {...context.toGlobalVariables(), ...request.globalVariables};
  }

  Future<dynamic> _withTimeout(Future<dynamic> future) {
    final timeout = config.executionTimeout;
    if (timeout == null) return future;
    return future.timeout(timeout);
  }
}
