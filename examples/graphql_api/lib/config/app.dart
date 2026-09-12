import 'package:vania/vania.dart';
import 'package:vania/service_provider.dart';
import 'package:vania_graphql/vania_graphql.dart';
import 'package:graphql_api/graphql/schema.dart';

Map<String, dynamic> config = {
  'name': env('APP_NAME', 'graphql_api'),
  'url': env('APP_URL', 'http://localhost'),
  'providers': <ServiceProvider>[
    GraphQLServiceProvider(schema: buildSchema()),
  ],
};
