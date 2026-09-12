# Vania GraphQL

**A GraphQL server for Vania — one provider, your schema, and an in-browser IDE for free.**

`vania_graphql` serves a GraphQL API from a Vania app. You describe your types and resolvers, hand the schema to a single provider, and it exposes one endpoint that answers both GET and POST. Open that endpoint in a browser and you get GraphiQL, an interactive IDE for exploring and running queries; point an API client at it and you get JSON. It also supports subscriptions for real-time data.

## Install

```yaml
dependencies:
  vania_graphql: ^1.0.0
```

Register the provider with your schema:

```dart
final providers = <ServiceProvider>[
  GraphQLServiceProvider(schema: buildSchema()),
];
```

That registers one route at `/graphql`.

## Build a schema

A schema is types plus resolvers — a resolver is just a function that returns a field's value:

```dart
import 'package:vania_graphql/vania_graphql.dart';

GraphQLSchema buildSchema() {
  return graphQLSchema(
    queryType: objectType('Query', fields: [
      vaniaField('hello', graphQLString, resolve: (_, _) => 'Hello from Vania'),
      vaniaField('books', listOf(bookType), resolve: (_, _) => books),
      vaniaField('book', bookType,
        inputs: [GraphQLFieldInput('id', graphQLInt.nonNullable())],
        resolve: (_, args) => findBook(args['id'])),
    ]),
  );
}
```

## Run queries

```graphql
{
  books { id title author }
  book(id: 2) { title }
}
```

A browser gets the GraphiQL IDE; a client `POST`s JSON and gets JSON back.

## Good to know

- **GraphiQL and introspection are off in production by default** — they publish your whole schema. The switch is `APP_ENV` (they default to on when it isn't `production`). Turn them on explicitly with `GRAPHQL_GRAPHIQL_ENABLED` / `GRAPHQL_INTROSPECTION_ENABLED` if you really mean to.
- **Subscriptions** are supported for pushing real-time updates to clients.
- Resolvers return plain data; field resolvers read from the parent via `context.rootValue`.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
