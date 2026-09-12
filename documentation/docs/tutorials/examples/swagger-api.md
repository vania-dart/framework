---
sidebar_position: 9
---

# Walkthrough: Swagger API

**Sample:** `examples/swagger_api` · **Needs:** nothing but Dart

A small products REST API documented with **Swagger / OpenAPI 3**. The API itself is an ordinary Vania feature; the interesting part is the separate file that *describes* those endpoints, which `SwaggerServiceProvider` turns into interactive docs served on the app's own port.

See the [Swagger](../../packages/swagger.md) package page for the full helper set.

## Run it

```bash
cd examples/swagger_api
dart pub get
dart run bin/server.dart
```

Open `http://localhost:8000/docs` for the interactive Swagger UI. The spec is also served at `/docs/swagger.json` and `/docs/swagger.yaml`.

## The shape of the sample

```
lib/
  features/products/    # the API being documented (a normal feature)
  features/auth/        # a tiny login + protected route
  docs/api_docs.dart    # the OpenAPI description — the point of this sample
  config/app.dart       # RouteServiceProvider + SwaggerServiceProvider
```

The API endpoints are a standard product CRUD feature (entity, repository, controller, routes) exactly like the [Todos](todos.md) sample — so this walkthrough focuses on the documentation layer.

## Turning metadata into docs

Two pieces in `config/app.dart` do the work:

```dart
// lib/config/app.dart
'providers': <ServiceProvider>[
  RouteServiceProvider(),
  SwaggerServiceProvider(
    info: const ApiInfo(
      title: 'Products API',
      version: '1.0.0',
      description: 'A small catalogue API documented with Swagger.',
    ),
  ),
],
```

`ApiInfo` is the title block. The endpoint descriptions are registered separately by `registerApiDocs()`, called from the route provider.

## Describing endpoints

`api_docs.dart` uses helper functions — one per endpoint — plus reusable schemas and tags:

```dart
// lib/docs/api_docs.dart
void registerApiDocs() {
  swaggerTag('Auth', description: 'Login and the current user');
  swaggerTag('Products', description: 'Manage the product catalogue');

  // Makes the "Authorize" button appear in Swagger UI so you can paste a token.
  swaggerAddBearerAuth();

  // A reusable schema, referenced by name from responses and bodies.
  swaggerRawSchema('Product', {
    'type': 'object',
    'properties': {
      'id': {'type': 'integer', 'example': 1},
      'name': {'type': 'string', 'example': 'Coffee mug'},
      'price_cents': {'type': 'integer', 'example': 1200},
    },
  });

  swaggerGet('/api/products',
    operation: const ApiOperation(summary: 'List products', tags: ['Products']),
    responses: const [
      ApiOkResponse(
        description: 'A list of products',
        rawSchema: {
          'type': 'object',
          'properties': {
            'data': {'type': 'array', 'items': {r'$ref': '#/components/schemas/Product'}},
          },
        },
      ),
    ],
  );

  swaggerPost('/api/products',
    operation: const ApiOperation(summary: 'Create a product', tags: ['Products']),
    body: const ApiBody(
      description: 'The product to create',
      rawSchema: {
        'type': 'object',
        'required': ['name', 'price_cents'],
        'properties': {
          'name': {'type': 'string', 'example': 'Coffee mug'},
          'price_cents': {'type': 'integer', 'example': 1200},
        },
      },
    ),
    responses: const [
      ApiCreatedResponse(description: 'The created product', schemaRef: '#/components/schemas/Product'),
      ApiUnprocessableEntityResponse(description: 'Validation failed'),
    ],
  );
  // ... swaggerGet('/api/products/{id}'), swaggerDelete('/api/products/{id}'), login, me
}
```

A few conventions worth noticing:

- **Define a schema once, reference it everywhere.** `swaggerRawSchema('Product', …)` registers the shape; responses point at it with `schemaRef: '#/components/schemas/Product'` (or a raw `$ref`). Change the schema in one place and every endpoint that uses it updates.
- **Tags group endpoints** in the UI (`Auth`, `Products`).
- **`swaggerAddBearerAuth()` plus `security:` on a route** is what puts the padlock and "Authorize" button in the UI, so you can log in via `/api/login`, paste the token, and try the protected `/api/me`.
- **Typed response helpers** (`ApiOkResponse`, `ApiCreatedResponse`, `ApiNotFoundResponse`, `ApiUnauthorizedResponse`, `ApiUnprocessableEntityResponse`) map to the status codes you would otherwise write out by hand.

## One wiring gotcha

A `Route` with a prefix sets a sticky base prefix on the router. The route provider clears it before the Swagger provider registers `/docs`, so the docs routes don't get pushed under `/api`:

```dart
// lib/app/providers/route_service_provider.dart
ProductsRoute().register();
AuthRoute().register();

Router.basePrefix(null);   // reset, so /docs is registered at the root
registerApiDocs();
```

If you ever find your docs served at `/api/docs` instead of `/docs`, this is why.

## The docs describe; they don't enforce

An important mental model: the Swagger description is *separate* from the API. Writing `required: ['name']` in the doc does not validate anything — the controller's `req.validate(...)` does that. The doc is a contract you keep in sync with the code, which is exactly why the sample has a test that generates the spec and asserts on its contents:

```bash
dart test   # swagger_docs_test.dart builds the spec and checks it
```

That test is your guard against the docs drifting away from reality.

## Security note

The docs describe every endpoint your API exposes — handy in development, but gate them behind auth or an allow-list before enabling in production. `SwaggerServiceProvider` accepts a `middleware:` argument for exactly that.

## What to take away

- Keep the OpenAPI description in its own file; register one entry per endpoint plus reusable schemas.
- **Define schemas once and `$ref` them** so the docs stay consistent.
- The docs *describe* the API — validation still lives in the controller. A generation test keeps the two in sync.
- Reset the router's base prefix before registering `/docs`, and gate the docs in production.
