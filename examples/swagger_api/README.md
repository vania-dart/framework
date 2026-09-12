# Swagger API Example

A small products REST API documented with **Swagger / OpenAPI 3** using the
[Vania](../../packages/core) framework and
[`vania_swagger`](../../packages/vania_swagger). It shows how to describe your
endpoints and serve interactive docs on the app's own HTTP port.

## How it works

1. The API itself is a normal Vania feature — entity, repository, controller,
   routes under [`lib/features/products/`](lib/features/products/).
2. [`lib/docs/api_docs.dart`](lib/docs/api_docs.dart) describes those endpoints
   with the `swagger*` helpers (`swaggerGet`, `swaggerPost`, `swaggerDelete`,
   `swaggerRawSchema`, …) — one reusable `Product` schema plus one entry per
   route.
3. `SwaggerServiceProvider` (added in [`config/app.dart`](lib/config/app.dart))
   turns that metadata into Swagger UI and the spec files.

```
lib/
  features/products/    # the API being documented
  docs/api_docs.dart    # the OpenAPI description (the point of this sample)
  config/app.dart       # RouteServiceProvider + SwaggerServiceProvider
bin/server.dart
test/
  product_repository_test.dart
  swagger_docs_test.dart   # generates the spec and asserts its contents
```

## Endpoints

| Method | Path                 | Documented as        |
|--------|----------------------|----------------------|
| GET    | `/api/products`      | List products        |
| POST   | `/api/products`      | Create a product     |
| GET    | `/api/products/{id}` | Get a product by id  |
| DELETE | `/api/products/{id}` | Delete a product     |

## Docs routes (served by `SwaggerServiceProvider`)

| Route                 | Response                 |
|-----------------------|--------------------------|
| `GET /docs`           | Swagger UI               |
| `GET /docs/swagger.json` | OpenAPI spec (JSON)   |
| `GET /docs/swagger.yaml` | OpenAPI spec (YAML)   |

## Running

```bash
dart pub get
dart run bin/server.dart
```

Then open <http://localhost:8000/docs> for the interactive Swagger UI.

> The docs describe every endpoint your API exposes — handy in development,
> but gate them behind auth or an allow-list before enabling in production
> (pass `middleware:` to `SwaggerServiceProvider`).

## Tests

The spec is generated in-process and asserted without a running server:

```bash
dart test
```
