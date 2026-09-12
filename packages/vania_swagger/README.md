# Vania Swagger

**Describe your API once, and serve interactive OpenAPI 3 docs from your own app.**

`vania_swagger` turns a description of your endpoints into a full OpenAPI 3.0 spec and a live Swagger UI, served on your app's own HTTP port. You write the description with a set of small helper functions — one per endpoint, plus reusable schemas and tags — and the provider does the rest: `/docs` for the UI, and the raw spec as JSON and YAML.

## Install

```yaml
dependencies:
  vania_swagger: ^1.0.0
```

Register the provider with your API's info block:

```dart
final providers = <ServiceProvider>[
  SwaggerServiceProvider(
    info: const ApiInfo(
      title: 'Products API',
      version: '1.0.0',
      description: 'A small catalogue API documented with Swagger.',
    ),
  ),
];
```

## Describe your endpoints

```dart
import 'package:vania_swagger/vania_swagger.dart';

void registerApiDocs() {
  swaggerTag('Products', description: 'Manage the catalogue');

  // Define a schema once, reference it everywhere
  swaggerRawSchema('Product', {
    'type': 'object',
    'properties': {
      'id': {'type': 'integer'},
      'name': {'type': 'string'},
      'price_cents': {'type': 'integer'},
    },
  });

  swaggerGet('/api/products',
    operation: const ApiOperation(summary: 'List products', tags: ['Products']),
    responses: const [ApiOkResponse(description: 'A list of products')],
  );
}
```

## See it

```
GET /docs             → Swagger UI
GET /docs/swagger.json → the spec (JSON)
GET /docs/swagger.yaml → the spec (YAML)
```

## Good to know

- Typed response helpers (`ApiOkResponse`, `ApiCreatedResponse`, `ApiNotFoundResponse`, `ApiUnauthorizedResponse`, …) map to the right status codes.
- `swaggerAddBearerAuth()` plus `security:` on a route adds the "Authorize" button so you can try protected endpoints.
- The docs *describe* your API — they don't validate it. Keep them honest with a test that generates the spec and asserts on it.
- The docs expose every endpoint, so gate `/docs` behind auth or an allow-list in production via the provider's `middleware:` option.

## Links

- Documentation: [vdart.dev/docs](https://vdart.dev/docs/intro)
- Source & issues: [github.com/vania-dart/framework](https://github.com/vania-dart/framework)

## License

MIT
