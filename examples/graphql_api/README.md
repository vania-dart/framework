# GraphQL API Example

A simple GraphQL API built with the [Vania](../../packages/core) framework and
[`vania_graphql`](../../packages/vania_graphql). Open the endpoint in a browser
and you get the **GraphiQL** web IDE (like the Apollo Sandbox) to explore and
run queries.

## The schema

```graphql
type Book { id: Int, title: String, author: String }

type Query {
  hello: String
  books: [Book]
  book(id: Int!): Book
}
```

It resolves against an in-memory list of books — see
[lib/graphql/schema.dart](lib/graphql/schema.dart). The whole app is wired in
[config/app.dart](lib/config/app.dart) with a single provider:

```dart
GraphQLServiceProvider(schema: buildSchema())
```

That registers one route that answers both GET and POST at `/graphql`.

## Open the IDE

Start the server and open the endpoint in a browser:

```bash
dart pub get
dart run bin/server.dart
```

→ <http://localhost:8000/graphql>

A browser sends `Accept: text/html`, so the endpoint returns the GraphiQL IDE.
Try:

```graphql
{
  books { id title author }
  book(id: 2) { title }
}
```

Programmatic clients POST instead:

```bash
curl -X POST http://localhost:8000/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ books { title } }"}'
```

## Enabling the IDE (important)

GraphiQL and introspection are **off in production by default** — they publish
your whole schema. The switch is `APP_ENV`, not `APP_DEBUG`:

- `isProduction = env('APP_ENV', 'production') == 'production'`
- `graphiqlEnabled` / `introspectionEnabled` default to `!isProduction`

So this example's [`.env`](.env) sets `APP_ENV=local`. Without it, `GET /graphql`
returns JSON errors instead of the IDE. (`APP_DEBUG=true` alone does **not**
enable it.) To serve the IDE in a production environment on purpose, set
`GRAPHQL_GRAPHIQL_ENABLED=true` and `GRAPHQL_INTROSPECTION_ENABLED=true`
explicitly.

## Tests

The schema is executed in-process, no server needed:

```bash
dart test
```
