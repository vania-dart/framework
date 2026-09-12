import 'package:graphql_schema2/graphql_schema2.dart';

class VaniaGraphQLErrorFormatter {
  const VaniaGraphQLErrorFormatter({required this.exposeExceptionDetails});

  final bool exposeExceptionDetails;

  Map<String, dynamic> fromGraphQLException(GraphQLException exception) {
    return exception.toJson();
  }

  Map<String, dynamic> fromException(Object error) {
    return {
      'errors': [
        {
          'message': exposeExceptionDetails
              ? error.toString()
              : 'Internal GraphQL server error.',
        },
      ],
    };
  }
}
