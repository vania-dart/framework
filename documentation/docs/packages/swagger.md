---
sidebar_position: 9
---

# Swagger / OpenAPI (vania_swagger)

The `vania_swagger` package builds an OpenAPI 3.2.0 specification from descriptions you register in code, and serves it together with a Swagger UI for exploring and trying the API.

The description is written by hand, endpoint by endpoint: the package does not read your routes or controllers. Keep each description next to the route it documents so the two change together.

## Installation

```yaml
dependencies:
  vania_swagger: ^1.0.0
```

## Setup

Add the service provider to the `providers` list of your config map:

```dart
import 'package:vania_swagger/vania_swagger.dart';

Map<String, dynamic> config = {
  // ...
  'providers': <ServiceProvider>[
    RouteServiceProvider(),
    const SwaggerServiceProvider(
      info: ApiInfo(
        title: 'My App API',
        version: '1.0.0',
        description: 'REST API for My App',
        contact: ApiContact(name: 'Dev Team', email: 'dev@example.com'),
        license: ApiLicense(name: 'MIT'),
      ),
    ),
  ],
};
```

This adds three routes to the app's own router, on the app's own port:

| Path | Description |
|------|-------------|
| `GET /docs` | Swagger UI |
| `GET /docs/swagger.json` | OpenAPI spec (JSON) |
| `GET /docs/swagger.yaml` | OpenAPI spec (YAML) |

### Production

The docs list every endpoint, parameter and schema of the API, so they are **off when `APP_ENV` is `production`, and an app that does not set `APP_ENV` counts as production**. Set `APP_ENV=local` while developing, or `SWAGGER_ENABLED=true` to serve them anyway. If you do serve them outside development, put them behind authentication:

```dart
SwaggerServiceProvider(
  info: const ApiInfo(title: 'My App API', version: '1.0.0'),
  middleware: [Authenticate()],
)
```

## Describing Routes

Each HTTP method has a helper that adds one operation to the spec: `swaggerGet`, `swaggerPost`, `swaggerPut`, `swaggerPatch`, `swaggerDelete` and `swaggerQuery`. For any other method, use `swaggerRoute(method: ..., path: ...)`. Call them where you register the routes:

```dart
import 'package:vania/route.dart';
import 'package:vania_swagger/vania_swagger.dart' hide ApiRoute;

class ApiRoute extends Route {
  @override
  String? get prefix => 'api';

  @override
  void register() {
    super.register();

    swaggerGet(
      '/api/users',
      operation: const ApiOperation(summary: 'List all users'),
      tags: ['Users'],
      query: const [ApiQuery(name: 'page', schema: 'integer')],
      responses: const [
        ApiOkResponse(
          description: 'A list of users',
          rawSchema: {
            'type': 'array',
            'items': {r'$ref': '#/components/schemas/User'},
          },
        ),
      ],
    );
    Router.get('/users', userController.index);

    swaggerPost(
      '/api/users',
      operation: const ApiOperation(summary: 'Create a user'),
      tags: ['Users'],
      body: const ApiBody(schemaRef: 'User'),
      responses: const [
        ApiCreatedResponse(description: 'User created', schemaRef: 'User'),
        ApiUnprocessableEntityResponse(description: 'Validation failed'),
      ],
    );
    Router.post('/users', userController.store);

    swaggerGet(
      '/api/users/{id}',
      operation: const ApiOperation(summary: 'Get a user by ID'),
      tags: ['Users'],
      params: const [ApiParam(name: 'id', schema: 'integer')],
      responses: const [
        ApiOkResponse(description: 'User found', schemaRef: 'User'),
        ApiNotFoundResponse(description: 'User not found'),
      ],
    );
    Router.get('/users/{id}', userController.show).whereInt('id');
  }
}
```

`vania_swagger` exports a class named `ApiRoute` too, so a route file named `ApiRoute`, as above, imports the package with `hide ApiRoute`.

Paths in the spec are the full paths the client calls, prefix included. `/users/:id` is written as `/users/{id}` for you.

### What an Operation Can Describe

All the helpers take these named arguments, except that `swaggerDelete` has no `query`:

| Argument | Type | Describes |
|----------|------|-----------|
| `operation` | `ApiOperation` | `summary`, `description`, `operationId`, `deprecated` |
| `tags` | `List<String>` | The groups the operation is listed under |
| `params` | `List<ApiParam>` | Path parameters (`location:` can also be `query`, `header` or `cookie`) |
| `query` | `List<ApiQuery>` | Query-string parameters |
| `headers` | `List<ApiHeader>` | Request headers |
| `responses` | `List<ApiResponse>` | Responses. Without any, a bare `200` is listed |
| `security` | `List<ApiSecurity>` | The [security schemes](#security-schemes) it requires |
| `produces` | `List<String>` | Response media types, `application/json` by default |
| `hidden` | `bool` | Leaves the operation out of the spec |

`swaggerPost`, `swaggerPut`, `swaggerPatch` and `swaggerQuery` also take a request `body` (an `ApiBody`) and `consumes`, its media types. `swaggerPost` and `swaggerQuery` take `fileUploads` as well.

A body or a response gets its schema from one of: `schemaRef: 'User'` (a [registered schema](#defining-schemas)), `schema: User` (a Dart type, referenced by its name), or `rawSchema:` (a JSON Schema map, used as is).

The response classes set the status code for you: `ApiOkResponse` (200), `ApiCreatedResponse` (201), `ApiNoContentResponse` (204), `ApiBadRequestResponse` (400), `ApiUnauthorizedResponse` (401), `ApiForbiddenResponse` (403), `ApiNotFoundResponse` (404) and `ApiUnprocessableEntityResponse` (422). For any other code, use `ApiResponse(statusCode: ...)`.

### File Uploads

```dart
swaggerPost(
  '/api/users/{id}/avatar',
  params: const [ApiParam(name: 'id', schema: 'integer')],
  fileUploads: const [
    ApiFileUpload(name: 'avatar', allowedTypes: ['image/png', 'image/jpeg']),
  ],
);
```

The body is documented as `multipart/form-data`, and Swagger UI shows a file picker.

### QUERY Operations

A [`QUERY` route](../core/routing.md#query-routes) is documented with `swaggerQuery`, which takes a request body like `swaggerPost`. List every media type the query may arrive in with `consumes`:

```dart
swaggerQuery(
  '/api/contacts',
  operation: const ApiOperation(summary: 'Search contacts'),
  body: const ApiBody(description: 'The query', rawSchema: {'type': 'object'}),
  consumes: ['application/json', 'application/sql'],
  tags: ['Contacts'],
);
Router.query('/contacts', contactController.search)
    .acceptQuery(['application/json', 'application/sql']);
```

It appears under the path's `query` field, which OpenAPI 3.2 added, and Swagger UI can send it from "Try it out". A method with no field of its own in OpenAPI, such as `PURGE`, is written under the path's `additionalOperations`, as 3.2 requires.

### About the Annotations

`ApiOperation`, `ApiParam`, `ApiOkResponse` and the other `Api*` classes have `const` constructors, so they can be written as annotations, and there are verb classes to go with them (`ApiGet`, `ApiPost`, `ApiPut`, `ApiPatch`, `ApiDelete`, and `ApiQueryMethod` for `QUERY`). **Nothing reads annotations, though.** That would take `dart:mirrors`, which ahead-of-time compiled apps cannot use, so an annotated controller method adds nothing to the spec. Pass the same objects to the helpers above instead.

## Defining Schemas

Register a schema once, then refer to it by name with `schemaRef` wherever it is used:

```dart
swaggerSchema(
  'User',
  properties: const [
    ApiProperty(name: 'id', type: 'integer', required: true),
    ApiProperty(name: 'name', type: 'string', required: true),
    ApiProperty(name: 'email', type: 'string', format: 'email', required: true),
    ApiProperty(name: 'created_at', type: 'string', format: 'date-time'),
  ],
);
```

Or give the JSON Schema directly:

```dart
swaggerRawSchema('User', {
  'type': 'object',
  'properties': {
    'id': {'type': 'integer'},
    'name': {'type': 'string'},
    'email': {'type': 'string', 'format': 'email'},
  },
  'required': ['id', 'name', 'email'],
});
```

## Security Schemes

Declare a scheme once, then list it in the `security` of each operation that needs it. Swagger UI adds an "Authorize" button for it.

### Bearer Token (JWT)

```dart
swaggerAddBearerAuth(); // registered as 'bearerAuth'

swaggerGet(
  '/api/profile',
  operation: const ApiOperation(summary: 'Get the current user'),
  security: const [ApiSecurity(scheme: 'bearerAuth')],
);
```

### API Key

```dart
swaggerAddApiKey(name: 'apiKey', headerName: 'X-API-Key');
```

`location:` places the key in the `ApiKeyLocation.header` (the default), `query` or `cookie`.

### Basic Auth

```dart
swaggerAddBasicAuth(); // registered as 'basicAuth'
```

### OAuth 2

```dart
swaggerAddOAuth2(
  name: 'oauth',
  authorizationUrl: 'https://auth.example.com/authorize',
  tokenUrl: 'https://auth.example.com/token',
  scopes: {'users:read': 'Read users'},
);
```

## Servers

The spec always lists one server first: the `server_url` setting if there is one, otherwise the address the docs were requested on. `swaggerServer` adds more after it:

```dart
swaggerServer('https://api.example.com', description: 'Production');
swaggerServer('http://localhost:8000', description: 'Local development');
```

## Tags

Tags group operations in Swagger UI. Describing a tag is optional:

```dart
swaggerTag('Users', description: 'User management endpoints');
swaggerTag(
  'Posts',
  description: 'Blog post CRUD operations',
  externalDocsUrl: 'https://example.com/docs/posts',
);
```

## Configuration Options

Pass a `SwaggerConfig` to the provider:

```dart
const SwaggerServiceProvider(
  info: ApiInfo(title: 'My API', version: '1.0.0'),
  config: SwaggerConfig(
    enabled: true,
    basePath: '/docs',
    title: 'My API Docs',
    serverUrl: 'https://api.example.com',
    corsEnabled: true,
  ),
)
```

Without one, the same settings come from the `swagger` entry of the config map, then from the environment:

| Config key | Environment variable | Default |
|------------|----------------------|---------|
| `enabled` | `SWAGGER_ENABLED` | `true`, except in production |
| `base_path` | `SWAGGER_BASE_PATH` | `/docs` |
| `title` | `SWAGGER_TITLE` | `API Documentation` (the page title) |
| `server_url` | `SWAGGER_SERVER_URL` | the address the docs were requested on |
| `cors` | `SWAGGER_CORS` | `true`: the spec can be fetched from another origin |

## Accessing the Spec Programmatically

```dart
final spec = SwaggerGenerator().generate(serverUrl: 'https://api.example.com');
final yaml = encodeYaml(spec);
```

This is also how to test the docs: register the descriptions, generate the spec, and assert on it. Call `SwaggerMetadata().clear()` between tests, since every description goes into one shared registry.
