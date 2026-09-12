---
sidebar_position: 7
---

# GraphQL (vania_graphql)

The `vania_graphql` package integrates a GraphQL server into your Vania application with HTTP and WebSocket transport, subscriptions, and GraphiQL IDE.

## Installation

```yaml
dependencies:
  vania_graphql: ^1.0.0
```

## Setup

### Define Your Schema

```dart
import 'package:vania_graphql/vania_graphql.dart';

final userType = objectType('User', fields: [
  field('id', graphQLInt.nonNullable()),
  field('name', graphQLString.nonNullable()),
  field('email', graphQLString.nonNullable()),
  field('posts', listOf(postType)),
]);

final postType = objectType('Post', fields: [
  field('id', graphQLInt.nonNullable()),
  field('title', graphQLString.nonNullable()),
  field('body', graphQLString.nonNullable()),
]);

final queryType = objectType('Query', fields: [
  vaniaField<Map<String, dynamic>>(
    'users',
    listOf(userType),
    resolve: (_, context) async {
      return await User().query.get();
    },
  ),
  vaniaField<Map<String, dynamic>>(
    'user',
    userType,
    inputs: [GraphQLFieldInput('id', graphQLInt.nonNullable())],
    resolve: (_, context) async {
      final id = context.args['id'];
      return await User().query.find(id);
    },
  ),
]);

final mutationType = objectType('Mutation', fields: [
  vaniaField<Map<String, dynamic>>(
    'createUser',
    userType,
    inputs: [
      GraphQLFieldInput('name', graphQLString.nonNullable()),
      GraphQLFieldInput('email', graphQLString.nonNullable()),
    ],
    resolve: (_, context) async {
      return await User().query.create({
        'name': context.args['name'],
        'email': context.args['email'],
      });
    },
  ),
]);

final schema = GraphQLSchema(
  queryType: queryType,
  mutationType: mutationType,
);
```

### Register the Provider

```dart
'providers': [
  RouteServiceProvider(),
  DatabaseServiceProvider(),
  GraphQLServiceProvider(schema: schema),
],
```

Or register manually:

```dart
VaniaGraphQL.schema(schema);
VaniaGraphQL.routes();
```

## Configuration

```dart
GraphQLServiceProvider(
  schema: schema,
  config: GraphQLConfig(
    endpoint: '/graphql',
    graphiqlEnabled: true,
    introspectionEnabled: true,
    allowGet: true,
    allowPost: true,
    allowSubscriptions: true,
    maxQueryLength: 10000,
    executionTimeout: Duration(seconds: 30),
  ),
);
```

## Using GraphQL

Once configured, your GraphQL endpoint is available at `/graphql`.

### Query

```graphql
query {
  users {
    id
    name
    email
  }
}
```

```graphql
query {
  user(id: 1) {
    name
    email
    posts {
      title
    }
  }
}
```

### Mutation

```graphql
mutation {
  createUser(name: "Alice", email: "alice@example.com") {
    id
    name
  }
}
```

## GraphiQL IDE

When `graphiqlEnabled` is `true` (the default in development), visit `/graphql` in your browser to access the interactive GraphiQL IDE with syntax highlighting, auto-completion, and documentation explorer.

## Subscriptions

Define subscription fields for real-time data:

```dart
final subscriptionType = objectType('Subscription', fields: [
  vaniaSubscriptionField<Map<String, dynamic>>(
    'newPost',
    postType,
    subscribe: (_, context) {
      return postStream; // a Stream<Map<String, dynamic>>
    },
  ),
]);

final schema = GraphQLSchema(
  queryType: queryType,
  mutationType: mutationType,
  subscriptionType: subscriptionType,
);
```

Subscriptions use the `graphql-transport-ws` WebSocket sub-protocol. Clients connect to the same `/graphql` endpoint via WebSocket.

## Context

The `VaniaGraphQLContext` gives resolvers access to the HTTP request:

```dart
vaniaField<Map<String, dynamic>>(
  'me',
  userType,
  resolve: (_, context) async {
    final user = context.request.user;
    if (user == null) throw GraphQLException.fromMessage('Not authenticated');
    return user;
  },
),
```

Available on the context: `request`, `ip`, `uri`, `user`, `method`, `header(name)`.

## Error Handling

Throw `GraphQLException` in resolvers to return structured errors:

```dart
throw GraphQLException.fromMessage('User not found');
```

Unhandled exceptions are caught and returned as internal errors.
