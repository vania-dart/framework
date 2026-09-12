---
sidebar_position: 9
---

# Swagger / OpenAPI (vania_swagger)

The `vania_swagger` package generates OpenAPI 3.1.0 specifications from your routes and annotations, and serves a Swagger UI for interactive API exploration.

## Installation

```yaml
dependencies:
  vania_swagger: ^1.0.0
```

## Setup

Register the service provider:

```dart
import 'package:vania_swagger/vania_swagger.dart';

'providers': [
  RouteServiceProvider(),
  SwaggerServiceProvider(
    info: ApiInfo(
      title: 'My App API',
      version: '1.0.0',
      description: 'REST API for My App',
      contact: ApiContact(name: 'Dev Team', email: 'dev@example.com'),
      license: ApiLicense(name: 'MIT'),
    ),
  ),
],
```

This mounts three endpoints:

| Path | Description |
|------|-------------|
| `GET /docs` | Swagger UI |
| `GET /docs/swagger.json` | OpenAPI spec (JSON) |
| `GET /docs/swagger.yaml` | OpenAPI spec (YAML) |

## Describing Routes

### Using Helper Functions

The simplest way — no annotations or mirrors required:

```dart
import 'package:vania_swagger/vania_swagger.dart';

class ApiRoute implements Route {
  @override
  void register() {
    Router.basePrefix('api');

    swaggerRoute(
      method: 'get',
      path: '/api/users',
      summary: 'List all users',
      tags: ['Users'],
      responses: {
        200: ApiOkResponse(
          description: 'A list of users',
          content: {'type': 'array', 'items': {'\$ref': '#/components/schemas/User'}},
        ),
      },
    );
    Router.get('/users', userController.index);

    swaggerRoute(
      method: 'post',
      path: '/api/users',
      summary: 'Create a user',
      tags: ['Users'],
      body: ApiBody(
        required: true,
        content: {
          'name': {'type': 'string'},
          'email': {'type': 'string', 'format': 'email'},
        },
      ),
      responses: {
        201: ApiCreatedResponse(description: 'User created'),
        422: ApiUnprocessableEntityResponse(description: 'Validation failed'),
      },
    );
    Router.post('/users', userController.store);
  }
}
```

### Using Annotations

Annotate controller methods (requires `dart:mirrors`):

```dart
class UserController extends Controller {
  @ApiOperation(summary: 'List all users', tags: ['Users'])
  @ApiOkResponse(description: 'Success')
  Future<Response> index() async { ... }

  @ApiOperation(summary: 'Create a user', tags: ['Users'])
  @ApiBody(required: true)
  @ApiCreatedResponse(description: 'User created')
  @ApiUnprocessableEntityResponse(description: 'Validation failed')
  Future<Response> store(Request req) async { ... }

  @ApiOperation(summary: 'Get a user by ID', tags: ['Users'])
  @ApiParam(name: 'id', in_: 'path', required: true)
  @ApiOkResponse(description: 'User found')
  @ApiNotFoundResponse(description: 'User not found')
  Future<Response> show(int id) async { ... }
}
```

Register annotated controllers with:

```dart
SwaggerModule.setup(controllers: [UserController], models: [User]);
```

## Defining Schemas

```dart
swaggerSchema('User', {
  'type': 'object',
  'properties': {
    'id': {'type': 'integer'},
    'name': {'type': 'string'},
    'email': {'type': 'string', 'format': 'email'},
    'created_at': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['id', 'name', 'email'],
});
```

Or use the annotation:

```dart
@ApiSchema(properties: {
  'id': ApiProperty(type: 'integer'),
  'name': ApiProperty(type: 'string'),
  'email': ApiProperty(type: 'string', format: 'email'),
})
class User extends Model { ... }
```

## Security Schemes

### Bearer Token (JWT)

```dart
swaggerAddBearerAuth();
```

Then reference it in route descriptions:

```dart
swaggerRoute(
  method: 'get',
  path: '/api/profile',
  summary: 'Get current user profile',
  security: [ApiSecurity(name: 'bearerAuth')],
  // ...
);
```

### API Key

```dart
swaggerAddApiKey(name: 'X-API-Key', in_: 'header');
```

### Basic Auth

```dart
swaggerAddBasicAuth();
```

## Server Configuration

```dart
swaggerServer(url: 'https://api.example.com', description: 'Production');
swaggerServer(url: 'http://localhost:8000', description: 'Local Development');
```

## Tags

```dart
swaggerTag('Users', description: 'User management endpoints');
swaggerTag('Posts', description: 'Blog post CRUD operations');
```

## Configuration Options

```dart
SwaggerServiceProvider(
  info: ApiInfo(title: 'My API', version: '1.0.0'),
  config: SwaggerConfig(
    enabled: true,
    basePath: '/docs',
    serverUrl: 'http://localhost:8000',
    corsEnabled: true,
  ),
);
```

## Accessing the Spec Programmatically

```dart
Map<String, dynamic> spec = SwaggerGenerator().generate(
  serverUrl: 'https://api.example.com',
);
```
