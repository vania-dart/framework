---
sidebar_position: 7
---

# Walkthrough: GraphQL API

**Sample:** `examples/graphql_api` · **Needs:** nothing but Dart

A GraphQL API served from a single provider. Open the endpoint in a browser and you get **GraphiQL**, an interactive IDE for exploring and running queries. The data is an in-memory list of books, so you can focus on how a schema is built and served.

See the [GraphQL](../../packages/graphql.md) package page for the full API.

## Run it

```bash
cd examples/graphql_api
dart pub get
dart run bin/server.dart
```

Then open `http://localhost:8000/graphql` in a browser and try:

```graphql
{
  books { id title author }
  book(id: 2) { title }
}
```

A programmatic client POSTs instead:

```bash
curl -X POST http://localhost:8000/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ books { title } }"}'
```

The same endpoint serves both: a browser sends `Accept: text/html` and gets the IDE; an API client sends JSON and gets JSON back.

## One provider wires the whole thing

```dart
// lib/config/app.dart
'providers': <ServiceProvider>[
  GraphQLServiceProvider(schema: buildSchema()),
],
```

That single provider registers one route answering GET and POST at `/graphql`. Everything else is the schema.

## The schema

GraphQL is typed. You describe your types and how to *resolve* each field — that is, where its value comes from. The sample builds a `Book` type and a `Query` type with three fields.

### The Book type

```dart
// lib/graphql/schema.dart
final GraphQLObjectType _bookType = objectType(
  'Book',
  fields: [
    vaniaField<int, int>('id', graphQLInt,
        resolve: (context, _) => (context.rootValue as Map)['id'] as int),
    vaniaField<String, String>('title', graphQLString,
        resolve: (context, _) => (context.rootValue as Map)['title'] as String),
    vaniaField<String, String>('author', graphQLString,
        resolve: (context, _) => (context.rootValue as Map)['author'] as String),
  ],
);
```

Each field has a **resolver** — a function that returns the field's value. Here every resolver reads one key from the parent object, which GraphQL exposes as `context.rootValue`. When a `book` query returns a map, these resolvers pull `id`, `title`, and `author` out of it.

### The Query type

`Query` is the entry point — the fields a client can ask for at the top level:

```dart
GraphQLSchema buildSchema() {
  return graphQLSchema(
    queryType: objectType('Query', fields: [
      vaniaField<String, String>('hello', graphQLString,
          resolve: (_, _) => 'Hello from Vania GraphQL'),

      vaniaField('books', listOf(_bookType),
          resolve: (_, _) => _books),               // returns the whole list

      vaniaField('book', _bookType,
          inputs: [GraphQLFieldInput('id', graphQLInt.nonNullable())],
          resolve: (_, arguments) {
            final id = arguments['id'];
            for (final book in _books) {
              if (book['id'] == id) return book;
            }
            return null;
          }),
    ]),
  );
}
```

Three things to read here:

- **`hello`** returns a constant — the simplest possible resolver.
- **`books`** returns the whole list; `listOf(_bookType)` says the field is `[Book]`. The client picks which fields of each book it wants; unrequested fields are never resolved.
- **`book`** takes an argument. `inputs:` declares `id: Int!` (the `nonNullable()` makes it required), and the resolver reads it from `arguments['id']` to find one book.

The resolver returns a plain `Map`; the `Book` type's own resolvers then read fields out of it. That two-step — parent resolver returns an object, field resolvers read from it — is the heart of how GraphQL walks a query.

## Enabling the IDE (the part people trip on)

GraphiQL and schema introspection are **off in production by default**, because they publish your whole schema. The switch is `APP_ENV`, not `APP_DEBUG`:

- `isProduction = env('APP_ENV', 'production') == 'production'`
- `graphiqlEnabled` / `introspectionEnabled` default to `!isProduction`

So this sample's `.env` sets `APP_ENV=local`. Without it, opening `/graphql` in a browser returns JSON errors instead of the IDE. Setting `APP_DEBUG=true` alone does **not** turn it on. To deliberately serve the IDE in production, set `GRAPHQL_GRAPHIQL_ENABLED=true` and `GRAPHQL_INTROSPECTION_ENABLED=true` explicitly — and gate the endpoint behind auth if you do.

## Testing

The schema is executed in-process, so tests run a query straight against `buildSchema()` and assert on the result — no server needed:

```bash
dart test
```

## What to take away

- A GraphQL API in Vania is **one provider plus a schema**.
- A schema is **types + resolvers**; a resolver is just a function returning a field's value.
- Parent resolvers return objects; field resolvers read from `context.rootValue`.
- Arguments are declared with `inputs:` and read from the resolver's `arguments` map.
- Keep GraphiQL/introspection off in production unless you mean to expose them; the switch is `APP_ENV`.
