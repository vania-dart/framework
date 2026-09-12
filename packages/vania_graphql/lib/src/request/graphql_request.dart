import 'dart:convert';

import '../context/graphql_context.dart';

class VaniaGraphQLRequest {
  VaniaGraphQLRequest({
    required this.query,
    this.operationName,
    Map<String, dynamic> variables = const {},
    Map<String, dynamic> extensions = const {},
    Map<String, dynamic> globalVariables = const {},
    this.context,
    this.rootValue,
  }) : variables = Map<String, dynamic>.from(variables),
       extensions = Map<String, dynamic>.from(extensions),
       globalVariables = Map<String, dynamic>.from(globalVariables);

  final String query;
  final String? operationName;
  final Map<String, dynamic> variables;
  final Map<String, dynamic> extensions;
  final Map<String, dynamic> globalVariables;
  final VaniaGraphQLContext? context;
  final Object? rootValue;

  factory VaniaGraphQLRequest.fromMap(
    Map<String, dynamic> data, {
    VaniaGraphQLContext? context,
    Object? rootValue,
    Map<String, dynamic> globalVariables = const {},
  }) {
    final query = data['query'];
    if (query is! String || query.trim().isEmpty) {
      throw const VaniaGraphQLRequestException('GraphQL query is required.');
    }

    return VaniaGraphQLRequest(
      query: query,
      operationName: _stringOrNull(data['operationName']),
      variables: _map(data['variables']),
      extensions: _map(data['extensions']),
      globalVariables: globalVariables,
      context: context,
      rootValue: rootValue,
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final string = value.toString();
    if (string.isEmpty) return null;
    return string;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value == null) return {};
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const VaniaGraphQLRequestException(
      'GraphQL variables and extensions must be JSON objects.',
    );
  }
}

class VaniaGraphQLRequestException implements Exception {
  const VaniaGraphQLRequestException(this.message);

  final String message;

  Map<String, dynamic> toJson() {
    return {
      'errors': [
        {'message': message},
      ],
    };
  }

  @override
  String toString() => message;
}
