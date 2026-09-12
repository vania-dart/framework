import 'package:test/test.dart';
import 'package:vania_swagger/vania_swagger.dart';

void main() {
  setUp(SwaggerMetadata().clear);

  group('SwaggerModule.registerRoute', () {
    test('registers annotated routes', () {
      SwaggerModule.registerRoute(
        method: 'GET',
        path: '/users',
        operation: const ApiOperation(
          summary: 'List users',
          operationId: 'listUsers',
        ),
        tags: ['Users'],
        responses: const [
          ApiOkResponse(description: 'A list of users', schemaRef: 'UserList'),
        ],
      );
      SwaggerModule.registerRoute(
        method: 'POST',
        path: '/users',
        operation: const ApiOperation(
          summary: 'Create user',
          operationId: 'createUser',
        ),
        tags: ['Users'],
        body: const ApiBody(description: 'Payload', schemaRef: 'CreateUserDto'),
        responses: const [
          ApiCreatedResponse(description: 'Created', schemaRef: 'User'),
          ApiBadRequestResponse(description: 'Validation failed'),
        ],
      );
      SwaggerModule.registerRoute(
        method: 'GET',
        path: '/users/{id}',
        operation: const ApiOperation(summary: 'Get one user'),
        tags: ['Users'],
        params: const [ApiParam(name: 'id')],
        responses: const [
          ApiOkResponse(schemaRef: 'User'),
          ApiNotFoundResponse(description: 'User not found'),
        ],
      );
      SwaggerModule.registerRoute(
        method: 'GET',
        path: '/users/secret',
        hidden: true,
      );

      final routes = SwaggerMetadata().routes.values.toList();
      final visible = routes.where((r) => !r.hidden).toList();
      final hidden = routes.where((r) => r.hidden).toList();

      expect(visible.map((r) => '${r.method} ${r.path}').toSet(), {
        'GET /users',
        'POST /users',
        'GET /users/{id}',
      });
      expect(hidden.map((r) => '${r.method} ${r.path}').toSet(), {
        'GET /users/secret',
      });

      final list = visible.firstWhere(
        (r) => r.path == '/users' && r.method == 'GET',
      );
      expect(list.operation?.summary, 'List users');
      expect(list.tags, ['Users']);
      expect(list.responses.map((r) => r.statusCode).toSet(), {200});

      final create = visible.firstWhere(
        (r) => r.path == '/users' && r.method == 'POST',
      );
      expect(create.body?.schemaRef, 'CreateUserDto');
      expect(create.responses.map((r) => r.statusCode).toSet(), {201, 400});
    });
  });

  group('SwaggerModule.registerModel', () {
    test('registers schema from properties', () {
      SwaggerModule.registerModel(
        'CreateUserDto',
        properties: const [
          ApiProperty(
            name: 'email',
            type: 'string',
            example: 'ada@example.com',
            required: true,
          ),
          ApiProperty(name: 'name', type: 'string', example: 'Ada Lovelace'),
        ],
      );

      final schema = SwaggerMetadata().schemas['CreateUserDto'];
      expect(schema, isNotNull);
      final props = schema!['properties'] as Map<String, dynamic>;
      expect(props.keys.toSet(), {'email', 'name'});
      expect(props['email']['type'], 'string');
      expect(props['email']['example'], 'ada@example.com');
      expect(schema['required'], ['email']);
    });
  });

  group('SwaggerModule.registerRoute (hidden route)', () {
    test('feeds SwaggerMetadata identically to annotations', () {
      SwaggerModule.registerRoute(
        method: 'GET',
        path: '/health',
        operation: const ApiOperation(summary: 'Healthcheck'),
        responses: const [ApiOkResponse(description: 'OK')],
      );

      final route = SwaggerMetadata().routes['GET:/health'];
      expect(route, isNotNull);
      expect(route!.operation?.summary, 'Healthcheck');
    });
  });
}
