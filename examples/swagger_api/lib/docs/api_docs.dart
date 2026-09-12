import 'package:vania_swagger/vania_swagger.dart';

/// Registers the OpenAPI description of the products API: one reusable
/// `Product` schema plus one entry per endpoint. The `SwaggerServiceProvider`
/// turns this metadata into the Swagger UI and the spec files.
void registerApiDocs() {
  swaggerTag('Auth', description: 'Login and the current user');
  swaggerTag('Products', description: 'Manage the product catalogue');

  // Registers the `bearerAuth` security scheme, which is what makes the
  // "Authorize" button appear in Swagger UI so you can paste a token.
  swaggerAddBearerAuth();

  swaggerPost(
    '/api/login',
    operation: const ApiOperation(
      summary: 'Log in and receive a bearer token',
      description: 'Demo credentials: username `demo`, password `password`.',
      tags: ['Auth'],
    ),
    body: const ApiBody(
      description: 'Credentials',
      rawSchema: {
        'type': 'object',
        'required': ['username', 'password'],
        'properties': {
          'username': {'type': 'string', 'example': 'demo'},
          'password': {'type': 'string', 'example': 'password'},
        },
      },
    ),
    responses: const [
      ApiOkResponse(
        description: 'The bearer token',
        rawSchema: {
          'type': 'object',
          'properties': {
            'token': {'type': 'string'},
            'token_type': {'type': 'string', 'example': 'Bearer'},
          },
        },
      ),
      ApiUnauthorizedResponse(description: 'Invalid credentials'),
    ],
  );

  swaggerGet(
    '/api/me',
    operation: const ApiOperation(
      summary: 'The authenticated user',
      tags: ['Auth'],
    ),
    security: const [ApiSecurity(scheme: 'bearerAuth')],
    responses: const [
      ApiOkResponse(
        description: 'The current user',
        rawSchema: {
          'type': 'object',
          'properties': {
            'username': {'type': 'string', 'example': 'demo'},
          },
        },
      ),
      ApiUnauthorizedResponse(description: 'Missing or invalid bearer token'),
    ],
  );

  // Reusable schema, referenced from responses/bodies by name.
  swaggerRawSchema('Product', {
    'type': 'object',
    'properties': {
      'id': {'type': 'integer', 'example': 1},
      'name': {'type': 'string', 'example': 'Coffee mug'},
      'price_cents': {'type': 'integer', 'example': 1200},
    },
  });

  swaggerGet(
    '/api/products',
    operation: const ApiOperation(
      summary: 'List products',
      tags: ['Products'],
    ),
    responses: const [
      ApiOkResponse(
        description: 'A list of products',
        rawSchema: {
          'type': 'object',
          'properties': {
            'data': {
              'type': 'array',
              'items': {r'$ref': '#/components/schemas/Product'},
            },
          },
        },
      ),
    ],
  );

  swaggerPost(
    '/api/products',
    operation: const ApiOperation(
      summary: 'Create a product',
      tags: ['Products'],
    ),
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
      ApiCreatedResponse(
        description: 'The created product',
        schemaRef: '#/components/schemas/Product',
      ),
      ApiUnprocessableEntityResponse(description: 'Validation failed'),
    ],
  );

  swaggerGet(
    '/api/products/{id}',
    operation: const ApiOperation(
      summary: 'Get a product by id',
      tags: ['Products'],
    ),
    params: const [
      ApiParam(name: 'id', description: 'Product id', schema: 'integer'),
    ],
    responses: const [
      ApiOkResponse(
        description: 'The product',
        schemaRef: '#/components/schemas/Product',
      ),
      ApiNotFoundResponse(description: 'Product not found'),
    ],
  );

  swaggerDelete(
    '/api/products/{id}',
    operation: const ApiOperation(
      summary: 'Delete a product',
      tags: ['Products'],
    ),
    params: const [
      ApiParam(name: 'id', description: 'Product id', schema: 'integer'),
    ],
    responses: const [
      ApiOkResponse(description: 'Deleted'),
      ApiNotFoundResponse(description: 'Product not found'),
    ],
  );
}
