import 'dart:async';

import 'package:graphql_schema2/graphql_schema2.dart';

import '../context/graphql_context.dart';

typedef VaniaGraphQLResolver<T> =
    FutureOr<T> Function(
      VaniaGraphQLContext context,
      Map<String, dynamic> arguments,
    );

typedef VaniaGraphQLSubscriptionResolver =
    FutureOr<Stream<Map<String, dynamic>>> Function(
      VaniaGraphQLContext context,
      Map<String, dynamic> arguments,
    );

GraphQLObjectField<T, Object?> vaniaField<T, Serialized>(
  String name,
  GraphQLType<T, Serialized> type, {
  Iterable<GraphQLFieldInput> inputs = const [],
  VaniaGraphQLResolver<T>? resolve,
  String? deprecationReason,
  String? description,
}) {
  return GraphQLObjectField<T, Object?>(
    name,
    type as GraphQLType<T, Object?>,
    arguments: inputs,
    resolve: resolve == null
        ? null
        : (source, arguments) {
            final context = _contextFrom(source, arguments);
            return resolve(context, arguments);
          },
    deprecationReason: deprecationReason,
    description: description,
  );
}

GraphQLObjectField<Object?, Object?> vaniaSubscriptionField<T, Serialized>(
  String name,
  GraphQLType<T, Serialized> type, {
  Iterable<GraphQLFieldInput> inputs = const [],
  required VaniaGraphQLSubscriptionResolver resolve,
  String? deprecationReason,
  String? description,
}) {
  return GraphQLObjectField<Object?, Object?>(
    name,
    type as GraphQLType<Object?, Object?>,
    arguments: inputs,
    resolve: (source, arguments) {
      final context = _contextFrom(source, arguments);
      return resolve(context, arguments);
    },
    deprecationReason: deprecationReason,
    description: description,
  );
}

VaniaGraphQLContext _contextFrom(
  Object? source,
  Map<String, dynamic> arguments,
) {
  final existing = arguments[VaniaGraphQLContext.variableKey];
  if (existing is VaniaGraphQLContext) return existing;
  if (source is VaniaGraphQLContext) return source;
  return VaniaGraphQLContext(rootValue: source);
}
