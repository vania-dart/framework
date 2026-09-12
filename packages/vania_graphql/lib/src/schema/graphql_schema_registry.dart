import 'dart:async';

import 'package:graphql_schema2/graphql_schema2.dart';

typedef VaniaGraphQLDefaultFieldResolver =
    FutureOr<T> Function<T>(
      T objectValue,
      String? fieldName,
      Map<String, dynamic> argumentValues,
    );

class GraphQLSchemaRegistry {
  static final GraphQLSchemaRegistry _singleton =
      GraphQLSchemaRegistry._internal();

  factory GraphQLSchemaRegistry() => _singleton;

  GraphQLSchemaRegistry._internal();

  GraphQLSchema? _schema;
  final List<GraphQLType> _customTypes = [];
  VaniaGraphQLDefaultFieldResolver? _defaultFieldResolver;

  bool get hasSchema => _schema != null;

  GraphQLSchema get schema {
    final schema = _schema;
    if (schema == null) {
      throw StateError('No GraphQL schema has been registered.');
    }
    return schema;
  }

  List<GraphQLType> get customTypes => List.unmodifiable(_customTypes);

  VaniaGraphQLDefaultFieldResolver? get defaultFieldResolver =>
      _defaultFieldResolver;

  void registerSchema(
    GraphQLSchema schema, {
    Iterable<GraphQLType> customTypes = const [],
    VaniaGraphQLDefaultFieldResolver? defaultFieldResolver,
  }) {
    _schema = schema;
    _customTypes
      ..clear()
      ..addAll(customTypes);
    _defaultFieldResolver = defaultFieldResolver;
  }

  void reset() {
    _schema = null;
    _customTypes.clear();
    _defaultFieldResolver = null;
  }
}
