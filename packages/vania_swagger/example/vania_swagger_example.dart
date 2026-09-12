import 'package:vania_swagger/vania_swagger.dart';

void main() {
  // Register routes using the AOT-safe API.
  SwaggerModule.registerRoute(
    method: 'GET',
    path: '/users',
    operation: const ApiOperation(
      summary: 'List users',
      operationId: 'listUsers',
    ),
    tags: ['Users'],
    query: const [
      ApiQuery(name: 'page', required: false),
      ApiQuery(name: 'per_page', required: false),
    ],
    responses: const [
      ApiOkResponse(description: 'A page of users', schemaRef: 'User'),
    ],
    security: const [ApiSecurity(scheme: 'bearerAuth')],
  );

  SwaggerModule.registerRoute(
    method: 'POST',
    path: '/users',
    operation: const ApiOperation(
      summary: 'Create user',
      operationId: 'createUser',
    ),
    tags: ['Users'],
    body: const ApiBody(schemaRef: 'CreateUserDto'),
    responses: const [
      ApiCreatedResponse(description: 'Created', schemaRef: 'User'),
      ApiBadRequestResponse(description: 'Validation failed'),
    ],
    security: const [ApiSecurity(scheme: 'bearerAuth')],
  );

  SwaggerModule.registerRoute(
    method: 'GET',
    path: '/users/{id}',
    operation: const ApiOperation(summary: 'Get one user'),
    tags: ['Users'],
    params: const [ApiParam(name: 'id')],
    responses: const [
      ApiOkResponse(description: 'User', schemaRef: 'User'),
      ApiNotFoundResponse(description: 'Not found'),
    ],
    security: const [ApiSecurity(scheme: 'bearerAuth')],
  );

  // Register models (DTOs).
  SwaggerModule.registerModel(
    'CreateUserDto',
    properties: const [
      ApiProperty(
        name: 'email',
        type: 'string',
        example: 'ada@example.com',
        required: true,
      ),
      ApiProperty(
        name: 'name',
        type: 'string',
        example: 'Ada Lovelace',
        required: true,
      ),
      ApiProperty(name: 'age', type: 'integer', example: 36, required: false),
    ],
  );

  SwaggerModule.registerModel(
    'User',
    properties: const [
      ApiProperty(name: 'id', type: 'integer', example: 1),
      ApiProperty(name: 'email', type: 'string', example: 'ada@example.com'),
      ApiProperty(name: 'name', type: 'string', example: 'Ada Lovelace'),
    ],
  );

  // Global security schemes + servers.
  SwaggerMetadata()
    ..addBearerAuth()
    ..addServer('http://localhost:8000', description: 'Local');

  // In your app boot, list SwaggerServiceProvider() among providers:
  //
  //     final providers = <ServiceProvider>[
  //       SwaggerServiceProvider(
  //         info: const ApiInfo(title: 'My API', version: '1.0.0'),
  //         config: const SwaggerConfig(basePath: '/docs'),
  //       ),
  //     ];
  //
  // From here the UI is browsable at http://localhost:8000/docs.

  // For this example, just print the spec so it's inspectable.
  final spec = SwaggerGenerator().generate();
  print(encodeYaml(spec));
}
