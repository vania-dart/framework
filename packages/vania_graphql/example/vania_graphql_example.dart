import 'package:vania_graphql/vania_graphql.dart';

/// Demonstrates the three ways to interact with vania_graphql:
///  1. Programmatic execution (no HTTP)
///  2. As a Vania [ServiceProvider], which mounts on the app's HTTP port
///  3. Subscriptions over the graphql-ws WebSocket protocol on the same port
Future<void> main() async {
  final schema = graphQLSchema(
    queryType: objectType(
      'Query',
      fields: [
        vaniaField<String, String>(
          'hello',
          graphQLString,
          inputs: [GraphQLFieldInput('name', graphQLString)],
          resolve: (context, arguments) {
            return 'Hello ${arguments['name'] ?? 'Vania'}';
          },
        ),
      ],
    ),
    subscriptionType: objectType(
      'Subscription',
      fields: [
        vaniaSubscriptionField<String, String>(
          'ticks',
          graphQLString,
          resolve: (context, arguments) => Stream.periodic(
            const Duration(seconds: 1),
            (i) => {'ticks': 'tick $i'},
          ).take(5),
        ),
      ],
    ),
  );

  // (1) Programmatic execution.
  VaniaGraphQL.schema(schema);
  final result = await VaniaGraphQL.execute(
    VaniaGraphQLRequest.fromMap({
      'query': r'query($name: String) { hello(name: $name) }',
      'variables': {'name': 'GraphQL'},
    }),
  );
  print(result.payload);

  // (2) & (3) Ship the schema through the ServiceProvider — GraphQL is
  //     mounted at /graphql on the app's HTTP port, and (because
  //     `subscriptionsOverWebSocket` defaults to true) subscriptions are
  //     available on /graphql/ws speaking the `graphql-transport-ws`
  //     subprotocol. Compatible with Apollo Client, urql, Relay.
  //
  //     final providers = <ServiceProvider>[
  //       GraphQLServiceProvider(schema: schema),
  //     ];
}
