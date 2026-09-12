import 'dart:convert';

import 'package:test/test.dart';
import 'package:vania_swagger/vania_swagger.dart';

void main() {
  setUp(() {
    SwaggerMetadata().clear();
  });

  group('ApiInfo', () {
    test('creates with required fields', () {
      const info = ApiInfo(title: 'My API', version: '1.0.0');
      expect(info.title, equals('My API'));
      expect(info.version, equals('1.0.0'));
    });

    test('creates with optional fields', () {
      const info = ApiInfo(
        title: 'My API',
        version: '2.0.0',
        description: 'Test API',
        contact: ApiContact(name: 'Test', email: 'test@test.com'),
        license: ApiLicense(name: 'MIT'),
      );
      expect(info.description, equals('Test API'));
      expect(info.contact!.name, equals('Test'));
      expect(info.license!.name, equals('MIT'));
    });
  });

  group('ApiOperation', () {
    test('creates with defaults', () {
      const op = ApiOperation();
      expect(op.summary, equals(''));
      expect(op.deprecated, isFalse);
      expect(op.tags, isEmpty);
    });

    test('creates with values', () {
      const op = ApiOperation(
        summary: 'Get users',
        description: 'Returns all users',
        operationId: 'getUsers',
        tags: ['users'],
      );
      expect(op.summary, equals('Get users'));
      expect(op.operationId, equals('getUsers'));
      expect(op.tags, contains('users'));
    });
  });

  group('ApiParam', () {
    test('creates path param', () {
      const param = ApiParam(
        name: 'id',
        description: 'User ID',
        location: ParamLocation.path,
      );
      expect(param.name, equals('id'));
      expect(param.location, equals(ParamLocation.path));
      expect(param.required, isTrue);
    });

    test('creates query param', () {
      const param = ApiParam(
        name: 'page',
        location: ParamLocation.query,
        required: false,
        schema: 'integer',
      );
      expect(param.required, isFalse);
      expect(param.schema, equals('integer'));
    });
  });

  group('ApiBody', () {
    test('creates with defaults', () {
      const body = ApiBody();
      expect(body.contentType, equals('application/json'));
      expect(body.required, isTrue);
    });
  });

  group('ApiResponse', () {
    test('creates with status code', () {
      const response = ApiResponse(statusCode: 200, description: 'Success');
      expect(response.statusCode, equals(200));
      expect(response.description, equals('Success'));
    });
  });

  group('SwaggerMetadata', () {
    test('stores API info', () {
      const info = ApiInfo(title: 'Test API');
      SwaggerMetadata().setApiInfo(info);
      expect(SwaggerMetadata().apiInfo!.title, equals('Test API'));
    });

    test('stores route metadata', () {
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'GET',
          path: '/users',
          operation: ApiOperation(summary: 'Get users'),
        ),
      );

      final route = SwaggerMetadata().getRoute('GET', '/users');
      expect(route, isNotNull);
      expect(route!.operation!.summary, equals('Get users'));
    });

    test('stores schemas', () {
      SwaggerMetadata().addSchema('User', {
        'type': 'object',
        'properties': {
          'id': {'type': 'integer'},
          'name': {'type': 'string'},
        },
      });

      expect(SwaggerMetadata().schemas.containsKey('User'), isTrue);
    });

    test('clears all metadata', () {
      SwaggerMetadata().setApiInfo(const ApiInfo(title: 'Test'));
      SwaggerMetadata().addRoute(
        const RouteMetadata(method: 'GET', path: '/test'),
      );
      SwaggerMetadata().clear();
      expect(SwaggerMetadata().apiInfo, isNull);
      expect(SwaggerMetadata().routes, isEmpty);
    });
  });

  group('SwaggerGenerator', () {
    test('generates minimal spec', () {
      SwaggerMetadata().setApiInfo(const ApiInfo(title: 'Test API'));
      final spec = SwaggerGenerator().generate();

      expect(spec['openapi'], equals('3.1.0'));
      expect(spec['info']['title'], equals('Test API'));
      expect(spec['paths'], isEmpty);
    });

    test('generates spec with paths', () {
      SwaggerMetadata().setApiInfo(const ApiInfo(title: 'Test API'));
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'GET',
          path: '/users',
          operation: ApiOperation(summary: 'Get all users'),
        ),
      );
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'POST',
          path: '/users',
          operation: ApiOperation(summary: 'Create user'),
          body: ApiBody(description: 'User data'),
        ),
      );

      final spec = SwaggerGenerator().generate();
      final paths = spec['paths'] as Map;

      expect(paths.containsKey('/users'), isTrue);
      expect(paths['/users']['get']['summary'], equals('Get all users'));
      expect(paths['/users']['post']['summary'], equals('Create user'));
    });

    test('generates spec with path parameters', () {
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'GET',
          path: '/users/{id}',
          params: [ApiParam(name: 'id', location: ParamLocation.path)],
        ),
      );

      final spec = SwaggerGenerator().generate();
      final params =
          (spec['paths']['/users/{id}']['get']['parameters']) as List;

      expect(params.length, equals(1));
      expect(params[0]['name'], equals('id'));
      expect(params[0]['in'], equals('path'));
    });

    test('generates spec with request body', () {
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'POST',
          path: '/users',
          body: ApiBody(description: 'User to create', schema: String),
        ),
      );

      final spec = SwaggerGenerator().generate();
      final requestBody = spec['paths']['/users']['post']['requestBody'];

      expect(requestBody['required'], isTrue);
      expect(requestBody['content']['application/json']['schema'], isNotNull);
    });

    test('generates spec with file upload', () {
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'POST',
          path: '/upload',
          fileUploads: [
            ApiFileUpload(name: 'file', description: 'Upload file'),
          ],
        ),
      );

      final spec = SwaggerGenerator().generate();
      final requestBody = spec['paths']['/upload']['post']['requestBody'];

      expect(requestBody['content']['multipart/form-data'], isNotNull);
    });

    test('generates spec with multiple file uploads', () {
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'POST',
          path: '/upload-multiple',
          fileUploads: [
            ApiFileUpload(name: 'avatar', description: 'Avatar image'),
            ApiFileUpload(
              name: 'cover',
              description: 'Cover image',
              required: false,
            ),
          ],
        ),
      );

      final spec = SwaggerGenerator().generate();
      final schema =
          spec['paths']['/upload-multiple']['post']['requestBody']['content']['multipart/form-data']['schema'];

      expect(schema['properties'].length, equals(2));
      expect(schema['required'], contains('avatar'));
    });

    test('generates spec with responses', () {
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'GET',
          path: '/users',
          responses: [
            ApiResponse(statusCode: 200, description: 'Success'),
            ApiResponse(statusCode: 404, description: 'Not found'),
          ],
        ),
      );

      final spec = SwaggerGenerator().generate();
      final responses = spec['paths']['/users']['get']['responses'];

      expect(responses.containsKey('200'), isTrue);
      expect(responses.containsKey('404'), isTrue);
      expect(responses['200']['description'], equals('Success'));
    });

    test('generates spec with query parameters', () {
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'GET',
          path: '/users',
          query: [
            ApiQuery(name: 'page', schema: 'integer'),
            ApiQuery(name: 'search', schema: 'string'),
          ],
        ),
      );

      final spec = SwaggerGenerator().generate();
      final params = spec['paths']['/users']['get']['parameters'] as List;

      expect(params.length, equals(2));
      expect(params[0]['in'], equals('query'));
    });

    test('generates spec with header parameters', () {
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'GET',
          path: '/users',
          headers: [
            ApiHeader(name: 'X-Custom-Header', description: 'Custom header'),
          ],
        ),
      );

      final spec = SwaggerGenerator().generate();
      final params = spec['paths']['/users']['get']['parameters'] as List;

      expect(params[0]['in'], equals('header'));
    });

    test('generates spec with security', () {
      SwaggerMetadata().addSecurityScheme({
        'name': 'bearerAuth',
        'type': 'http',
        'scheme': 'bearer',
        'bearerFormat': 'JWT',
      });

      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'GET',
          path: '/protected',
          security: [ApiSecurity(scheme: 'bearerAuth')],
        ),
      );

      final spec = SwaggerGenerator().generate();
      final security = spec['paths']['/protected']['get']['security'] as List;

      expect(security.first.containsKey('bearerAuth'), isTrue);
    });

    test('generates Nest-style bearer and api key security schemes', () {
      SwaggerMetadata()
        ..addBearerAuth(name: 'access-token', description: 'JWT access token')
        ..addApiKey(name: 'x-api-key', headerName: 'X-API-Key');

      final spec = SwaggerGenerator().generate();
      final schemes = spec['components']['securitySchemes'];

      expect(schemes['access-token']['scheme'], equals('bearer'));
      expect(schemes['access-token']['bearerFormat'], equals('JWT'));
      expect(schemes['x-api-key']['type'], equals('apiKey'));
      expect(schemes['x-api-key']['name'], equals('X-API-Key'));
    });

    test('generates rich schemas with required, enum, arrays, and refs', () {
      SwaggerMetadata().addSchemaFromProperties('CreateUserDto', const [
        ApiProperty(
          name: 'email',
          type: 'string',
          format: 'email',
          required: true,
        ),
        ApiProperty(
          name: 'roles',
          type: 'string',
          isArray: true,
          enumValues: ['admin', 'user'],
        ),
        ApiProperty(name: 'profile', ref: 'ProfileDto'),
      ], description: 'User creation payload');

      final spec = SwaggerGenerator().generate();
      final schema = spec['components']['schemas']['CreateUserDto'];

      expect(schema['description'], equals('User creation payload'));
      expect(schema['required'], contains('email'));
      expect(schema['properties']['roles']['type'], equals('array'));
      expect(schema['properties']['roles']['items']['enum'], contains('admin'));
      expect(
        schema['properties']['profile']['\$ref'],
        equals('#/components/schemas/ProfileDto'),
      );
    });

    test('generates oneOf response schemas and route content negotiation', () {
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'GET',
          path: '/search',
          produces: ['application/json', 'application/problem+json'],
          responses: [
            ApiResponse(
              statusCode: 200,
              description: 'Search result',
              oneOf: [String, int],
            ),
          ],
        ),
      );

      final spec = SwaggerGenerator().generate();
      final content =
          spec['paths']['/search']['get']['responses']['200']['content'];

      expect(content.keys, contains('application/json'));
      expect(content.keys, contains('application/problem+json'));
      expect(content['application/json']['schema']['oneOf'], hasLength(2));
    });

    test('generates spec with tags', () {
      SwaggerMetadata().addRoute(
        const RouteMetadata(method: 'GET', path: '/users', tags: ['users']),
      );
      SwaggerMetadata().addRoute(
        const RouteMetadata(method: 'GET', path: '/posts', tags: ['posts']),
      );

      final spec = SwaggerGenerator().generate();
      final tags = spec['tags'] as List;

      expect(tags.length, equals(2));
      expect(tags[0]['name'], equals('users'));
      expect(tags[1]['name'], equals('posts'));
    });

    test('hides hidden routes', () {
      SwaggerMetadata().addRoute(
        const RouteMetadata(method: 'GET', path: '/internal', hidden: true),
      );

      final spec = SwaggerGenerator().generate();
      final paths = spec['paths'] as Map;

      expect(paths.containsKey('/internal'), isFalse);
    });

    test('generates spec with servers', () {
      SwaggerMetadata().setApiInfo(const ApiInfo(title: 'Test'));
      final spec = SwaggerGenerator().generate(
        serverUrl: 'http://localhost:3000',
      );

      expect(spec['servers'], isA<List>());
      expect(
        (spec['servers'] as List).first['url'],
        equals('http://localhost:3000'),
      );
    });

    test('generates spec with schemas', () {
      SwaggerMetadata().addSchema('User', {
        'type': 'object',
        'properties': {
          'id': {'type': 'integer'},
          'name': {'type': 'string'},
        },
      });

      final spec = SwaggerGenerator().generate();
      final schemas = spec['components']['schemas'];

      expect(schemas.containsKey('User'), isTrue);
      expect(schemas['User']['type'], equals('object'));
    });

    test('generates valid JSON', () {
      SwaggerMetadata().setApiInfo(
        const ApiInfo(
          title: 'Test API',
          version: '1.0.0',
          description: 'A test API',
        ),
      );
      SwaggerMetadata().addRoute(
        const RouteMetadata(
          method: 'GET',
          path: '/health',
          operation: ApiOperation(summary: 'Health check'),
        ),
      );

      final spec = SwaggerGenerator().generate();
      final json = jsonEncode(spec);
      final decoded = jsonDecode(json);

      expect(decoded['openapi'], equals('3.1.0'));
      expect(decoded['info']['title'], equals('Test API'));
    });
  });

  group('SwaggerHelpers', () {
    test('swaggerGet registers GET route', () {
      swaggerGet(
        '/users',
        operation: ApiOperation(summary: 'List users'),
        tags: ['users'],
      );

      final route = SwaggerMetadata().getRoute('GET', '/users');
      expect(route, isNotNull);
      expect(route!.operation!.summary, equals('List users'));
    });

    test('swaggerPost registers POST route', () {
      swaggerPost(
        '/users',
        operation: ApiOperation(summary: 'Create user'),
        body: ApiBody(description: 'User data'),
      );

      final route = SwaggerMetadata().getRoute('POST', '/users');
      expect(route, isNotNull);
      expect(route!.body!.description, equals('User data'));
    });

    test('swaggerPut registers PUT route', () {
      swaggerPut(
        '/users/{id}',
        params: [ApiParam(name: 'id', location: ParamLocation.path)],
      );

      final route = SwaggerMetadata().getRoute('PUT', '/users/{id}');
      expect(route, isNotNull);
      expect(route!.params.first.name, equals('id'));
    });

    test('swaggerDelete registers DELETE route', () {
      swaggerDelete('/users/{id}');

      final route = SwaggerMetadata().getRoute('DELETE', '/users/{id}');
      expect(route, isNotNull);
    });

    test('swaggerRoute registers custom method', () {
      swaggerRoute(
        method: 'PATCH',
        path: '/users/{id}',
        operation: ApiOperation(summary: 'Partial update'),
      );

      final route = SwaggerMetadata().getRoute('PATCH', '/users/{id}');
      expect(route, isNotNull);
    });

    test('swagger helpers register bearer auth and model schemas', () {
      swaggerAddBearerAuth(name: 'bearerAuth');
      swaggerSchema(
        'TokenResponse',
        properties: const [
          ApiProperty(name: 'access_token', type: 'string', required: true),
        ],
      );

      final spec = SwaggerGenerator().generate();

      expect(spec['components']['securitySchemes']['bearerAuth'], isNotNull);
      expect(
        spec['components']['schemas']['TokenResponse']['required'],
        contains('access_token'),
      );
    });
  });
}
