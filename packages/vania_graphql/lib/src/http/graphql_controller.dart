import 'dart:io';

import 'package:vania/http/request.dart' show Request;
import 'package:vania/http/response.dart' show Response;

import '../config/graphql_config.dart';
import '../context/graphql_context.dart';
import '../executor/vania_graphql_executor.dart';
import '../request/graphql_request.dart';
import 'graphql_graphiql_page.dart';

class VaniaGraphQLController {
  VaniaGraphQLController({GraphQLConfig? config})
    : config = config ?? GraphQLConfig.fromApplication();

  final GraphQLConfig config;

  Future<Response> handle(Request request) async {
    if (_isDisallowedMethod(request)) {
      return _jsonError('GraphQL endpoint only accepts GET and POST.', 405);
    }

    if (_shouldRenderGraphiQL(request)) {
      return Response.html(
        GraphiQLPage.render(
          endpoint: config.endpoint,
          subscriptionsEndpoint:
              config.allowSubscriptions && config.subscriptionsOverWebSocket
              ? config.subscriptionsEndpoint
              : null,
        ),
        headers: config.responseHeaders,
      );
    }

    try {
      final graphQLRequest = VaniaGraphQLRequest.fromMap(
        _payload(request),
        context: VaniaGraphQLContext(request: request),
      );
      final result = await VaniaGraphQLExecutor(
        config: config,
      ).execute(graphQLRequest);

      if (result.isStream) {
        return Response.sse(
          result.stream!,
          headers: {
            ...config.responseHeaders,
            HttpHeaders.cacheControlHeader: 'no-cache',
          },
        );
      }

      return Response.jsonWithHeader(
        result.payload,
        statusCode: result.statusCode,
        headers: config.responseHeaders,
      );
    } on VaniaGraphQLRequestException catch (error) {
      return Response.jsonWithHeader(
        error.toJson(),
        statusCode: 400,
        headers: config.responseHeaders,
      );
    }
  }

  bool _isDisallowedMethod(Request request) {
    final method = request.request.method.toUpperCase();
    if (method == 'GET') return !config.allowGet;
    if (method == 'POST') return !config.allowPost;
    return true;
  }

  bool _shouldRenderGraphiQL(Request request) {
    if (!config.graphiqlEnabled) return false;
    if (request.request.method.toUpperCase() != 'GET') return false;
    if (request.uri.queryParameters.containsKey('query')) return false;
    return request.request.headers
            .value(HttpHeaders.acceptHeader)
            ?.contains('text/html') ==
        true;
  }

  Map<String, dynamic> _payload(Request request) {
    if (request.request.method.toUpperCase() == 'GET') {
      return Map<String, dynamic>.from(request.uri.queryParameters);
    }
    return Map<String, dynamic>.from(request.body);
  }

  Response _jsonError(String message, int statusCode) {
    return Response.jsonWithHeader(
      {
        'errors': [
          {'message': message},
        ],
      },
      statusCode: statusCode,
      headers: config.responseHeaders,
    );
  }
}
