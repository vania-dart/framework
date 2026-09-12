class ApiOperation {
  final String summary;
  final String description;
  final String operationId;
  final bool deprecated;
  final List<String> tags;
  final String? externalDocsUrl;
  final String? externalDocsDescription;
  final Map<String, dynamic> extensions;

  const ApiOperation({
    this.summary = '',
    this.description = '',
    this.operationId = '',
    this.deprecated = false,
    this.tags = const [],
    this.externalDocsUrl,
    this.externalDocsDescription,
    this.extensions = const {},
  });
}

class ApiTags {
  final List<String> tags;

  const ApiTags(this.tags);
}

class ApiParam {
  final String name;
  final String? description;
  final bool required;
  final ParamLocation location;
  final String? schema;
  final String? example;
  final String? format;
  final List<String>? enumValues;
  final bool isArray;
  final bool allowEmptyValue;
  final bool deprecated;
  final String? style;
  final bool? explode;

  const ApiParam({
    required this.name,
    this.description,
    this.required = true,
    this.location = ParamLocation.path,
    this.schema,
    this.example,
    this.format,
    this.enumValues,
    this.isArray = false,
    this.allowEmptyValue = false,
    this.deprecated = false,
    this.style,
    this.explode,
  });
}

enum ParamLocation { path, query, header, cookie }

class ApiBody {
  final String description;
  final String? contentType;
  final List<String> contentTypes;
  final Type? schema;
  final String? schemaRef;
  final Map<String, dynamic>? rawSchema;
  final bool required;
  final String? example;
  final Map<String, dynamic>? examples;

  const ApiBody({
    this.description = '',
    this.contentType = 'application/json',
    this.contentTypes = const [],
    this.schema,
    this.schemaRef,
    this.rawSchema,
    this.required = true,
    this.example,
    this.examples,
  });
}

class ApiResponse {
  final int statusCode;
  final String description;
  final Type? schema;
  final String? schemaRef;
  final Map<String, dynamic>? rawSchema;
  final List<Type> oneOf;
  final List<Type> anyOf;
  final List<Type> allOf;
  final List<String> contentTypes;
  final String? example;
  final Map<String, dynamic>? examples;
  final Map<String, String>? headers;

  const ApiResponse({
    required this.statusCode,
    this.description = '',
    this.schema,
    this.schemaRef,
    this.rawSchema,
    this.oneOf = const [],
    this.anyOf = const [],
    this.allOf = const [],
    this.contentTypes = const [],
    this.example,
    this.examples,
    this.headers,
  });
}

class ApiOkResponse extends ApiResponse {
  const ApiOkResponse({
    super.description = '',
    super.schema,
    super.schemaRef,
    super.rawSchema,
    super.oneOf = const [],
    super.anyOf = const [],
    super.allOf = const [],
    super.contentTypes = const [],
    super.example,
    super.examples,
    super.headers,
  }) : super(statusCode: 200);
}

class ApiCreatedResponse extends ApiResponse {
  const ApiCreatedResponse({
    super.description = '',
    super.schema,
    super.schemaRef,
    super.rawSchema,
    super.oneOf = const [],
    super.anyOf = const [],
    super.allOf = const [],
    super.contentTypes = const [],
    super.example,
    super.examples,
    super.headers,
  }) : super(statusCode: 201);
}

class ApiNoContentResponse extends ApiResponse {
  const ApiNoContentResponse({super.description = '', super.headers})
    : super(statusCode: 204);
}

class ApiBadRequestResponse extends ApiResponse {
  const ApiBadRequestResponse({
    super.description = '',
    super.schema,
    super.schemaRef,
    super.rawSchema,
    super.example,
    super.examples,
    super.headers,
  }) : super(statusCode: 400);
}

class ApiUnauthorizedResponse extends ApiResponse {
  const ApiUnauthorizedResponse({
    super.description = '',
    super.schema,
    super.schemaRef,
    super.rawSchema,
    super.example,
    super.examples,
    super.headers,
  }) : super(statusCode: 401);
}

class ApiForbiddenResponse extends ApiResponse {
  const ApiForbiddenResponse({
    super.description = '',
    super.schema,
    super.schemaRef,
    super.rawSchema,
    super.example,
    super.examples,
    super.headers,
  }) : super(statusCode: 403);
}

class ApiNotFoundResponse extends ApiResponse {
  const ApiNotFoundResponse({
    super.description = '',
    super.schema,
    super.schemaRef,
    super.rawSchema,
    super.example,
    super.examples,
    super.headers,
  }) : super(statusCode: 404);
}

class ApiUnprocessableEntityResponse extends ApiResponse {
  const ApiUnprocessableEntityResponse({
    super.description = '',
    super.schema,
    super.schemaRef,
    super.rawSchema,
    super.example,
    super.examples,
    super.headers,
  }) : super(statusCode: 422);
}

class ApiResponses {
  final List<ApiResponse> responses;

  const ApiResponses(this.responses);
}

class ApiSecurity {
  final String scheme;
  final List<String> scopes;

  const ApiSecurity({required this.scheme, this.scopes = const []});
}

class ApiBearerAuth {
  final String name;
  final String? description;
  final List<String> scopes;
  final String bearerFormat;

  const ApiBearerAuth({
    this.name = 'bearerAuth',
    this.description,
    this.scopes = const [],
    this.bearerFormat = 'JWT',
  });
}

class ApiBasicAuth {
  final String name;
  final String? description;

  const ApiBasicAuth({this.name = 'basic', this.description});
}

class ApiOAuth2 {
  final String name;
  final String? description;
  final Map<String, String> scopes;
  final String? authorizationUrl;
  final String? tokenUrl;
  final String? refreshUrl;

  const ApiOAuth2({
    required this.name,
    this.description,
    this.scopes = const {},
    this.authorizationUrl,
    this.tokenUrl,
    this.refreshUrl,
  });
}

class ApiKeyAuth {
  final String name;
  final String headerName;
  final ApiKeyLocation location;
  final String? description;

  const ApiKeyAuth({
    this.name = 'apiKey',
    this.headerName = 'X-API-Key',
    this.location = ApiKeyLocation.header,
    this.description,
  });
}

enum ApiKeyLocation { query, header, cookie }

class ApiHeader {
  final String name;
  final String? description;
  final bool required;
  final String? schema;
  final String? example;
  final String? format;
  final List<String>? enumValues;
  final bool isArray;

  const ApiHeader({
    required this.name,
    this.description,
    this.required = false,
    this.schema,
    this.example,
    this.format,
    this.enumValues,
    this.isArray = false,
  });
}

class ApiQuery {
  final String name;
  final String? description;
  final bool required;
  final String? schema;
  final String? example;
  final String? format;
  final List<String>? enumValues;
  final bool isArray;
  final bool allowEmptyValue;
  final bool deprecated;

  const ApiQuery({
    required this.name,
    this.description,
    this.required = false,
    this.schema,
    this.example,
    this.format,
    this.enumValues,
    this.isArray = false,
    this.allowEmptyValue = false,
    this.deprecated = false,
  });
}

class ApiFileUpload {
  final String name;
  final String description;
  final bool required;
  final List<String> allowedTypes;

  const ApiFileUpload({
    required this.name,
    this.description = '',
    this.required = true,
    this.allowedTypes = const ['*/*'],
  });
}

class ApiHide {
  const ApiHide();
}

class ApiExclude {
  const ApiExclude();
}

class ApiConsumes {
  final List<String> contentTypes;

  const ApiConsumes(this.contentTypes);
}

class ApiProduces {
  final List<String> contentTypes;

  const ApiProduces(this.contentTypes);
}

class ApiExtraModels {
  final List<Type> models;

  const ApiExtraModels(this.models);
}

/// Declares the HTTP method + path for a Swagger route.
///
/// Use [SwaggerModule.registerRoute] to add routes to the spec.
/// Prefer the verb helpers ([ApiGet], [ApiPost], ...) when documenting
/// routes inline — they read better.
class ApiRoute {
  final String method;
  final String path;

  const ApiRoute(this.method, this.path);
}

class ApiGet extends ApiRoute {
  const ApiGet(String path) : super('GET', path);
}

class ApiPost extends ApiRoute {
  const ApiPost(String path) : super('POST', path);
}

class ApiPut extends ApiRoute {
  const ApiPut(String path) : super('PUT', path);
}

class ApiPatch extends ApiRoute {
  const ApiPatch(String path) : super('PATCH', path);
}

class ApiDelete extends ApiRoute {
  const ApiDelete(String path) : super('DELETE', path);
}
