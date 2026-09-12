import 'package:test/test.dart';
import 'package:vania/route.dart' show Router;
import 'package:vania_graphql/vania_graphql.dart';

void main() {
  setUp(VaniaGraphQL.resetForTesting);

  test('builds GraphQL config from application config', () {
    final config = const GraphQLConfig(
      endpoint: '/api/graphql',
      introspectionEnabled: false,
      maxQueryLength: 1200,
      executionTimeout: Duration(seconds: 2),
    );

    expect(config.endpoint, '/api/graphql');
    expect(config.introspectionEnabled, isFalse);
    expect(config.maxQueryLength, 1200);
    expect(config.executionTimeout, const Duration(seconds: 2));
  });

  test('parses variables and operation name from request maps', () {
    final request = VaniaGraphQLRequest.fromMap({
      'query': 'query Hello(\$name: String) { hello(name: \$name) }',
      'operationName': 'Hello',
      'variables': '{"name":"Vania"}',
    });

    expect(request.operationName, 'Hello');
    expect(request.variables, {'name': 'Vania'});
  });

  test('executes queries with Vania context aware resolvers', () async {
    VaniaGraphQL.schema(_schema());

    final result = await VaniaGraphQL.execute(
      VaniaGraphQLRequest.fromMap({
        'query': 'query Hello(\$name: String) { hello(name: \$name) }',
        'operationName': 'Hello',
        'variables': {'name': 'Vania'},
      }),
    );

    expect(result.isStream, isFalse);
    expect(result.payload, {
      'data': {'hello': 'Hello Vania'},
    });
  });

  test('returns GraphQL errors without throwing to callers', () async {
    VaniaGraphQL.schema(_schema());

    final result = await VaniaGraphQL.execute(
      VaniaGraphQLRequest.fromMap({'query': '{ hello('}),
    );

    expect(result.payload?['errors'], isA<List>());
  });

  test('streams subscription results as GraphQL response events', () async {
    VaniaGraphQL.schema(_schema());

    final result = await VaniaGraphQL.execute(
      VaniaGraphQLRequest.fromMap({'query': 'subscription { tick }'}),
    );

    expect(result.isStream, isTrue);
    await expectLater(
      result.stream,
      emitsInOrder([
        {
          'data': {'tick': 'one'},
        },
        emitsDone,
      ]),
    );
  });

  test('registers schema through service provider', () async {
    final provider = GraphQLServiceProvider(
      schema: _schema(),
      config: const GraphQLConfig(routeEnabled: false),
    );

    await provider.register();

    expect(GraphQLSchemaRegistry().hasSchema, isTrue);
  });

  test('registers GraphQL endpoint in Vania router', () {
    const endpoint = '/__graphql_test';

    GraphQLRouteRegistrar().register(
      config: const GraphQLConfig(endpoint: endpoint),
    );

    expect(Router().routes.any((route) => route.path == endpoint), isTrue);
  });
}

GraphQLSchema _schema() {
  return graphQLSchema(
    queryType: objectType(
      'Query',
      fields: [
        vaniaField<String, String>(
          'hello',
          graphQLString,
          inputs: [GraphQLFieldInput('name', graphQLString)],
          resolve: (context, arguments) {
            return 'Hello ${arguments['name'] ?? 'World'}';
          },
        ),
      ],
    ),
    subscriptionType: objectType(
      'Subscription',
      fields: [
        vaniaSubscriptionField<String, String>(
          'tick',
          graphQLString,
          resolve: (context, arguments) {
            return Stream.value({'tick': 'one'});
          },
        ),
      ],
    ),
  );
}
