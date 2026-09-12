import '../annotations/annotations.dart';
import 'swagger_metadata.dart';

void swaggerRoute({
  required String method,
  required String path,
  ApiOperation? operation,
  List<ApiParam>? params,
  ApiBody? body,
  List<ApiResponse>? responses,
  List<ApiSecurity>? security,
  List<ApiHeader>? headers,
  List<ApiQuery>? query,
  List<ApiFileUpload>? fileUploads,
  bool hidden = false,
  List<String>? tags,
  List<String>? consumes,
  List<String>? produces,
  Map<String, dynamic>? extensions,
}) {
  SwaggerMetadata().addRoute(
    RouteMetadata(
      method: method.toUpperCase(),
      path: path,
      operation: operation,
      params: params ?? const [],
      body: body,
      responses: responses ?? const [],
      security: security ?? const [],
      headers: headers ?? const [],
      query: query ?? const [],
      fileUploads: fileUploads ?? const [],
      hidden: hidden,
      tags: tags ?? const [],
      consumes: consumes ?? const [],
      produces: produces ?? const [],
      extensions: extensions ?? const {},
    ),
  );
}

void swaggerGet(
  String path, {
  ApiOperation? operation,
  List<ApiParam>? params,
  List<ApiResponse>? responses,
  List<ApiSecurity>? security,
  List<ApiHeader>? headers,
  List<ApiQuery>? query,
  bool hidden = false,
  List<String>? tags,
  List<String>? produces,
  Map<String, dynamic>? extensions,
}) {
  swaggerRoute(
    method: 'GET',
    path: path,
    operation: operation,
    params: params,
    responses: responses,
    security: security,
    headers: headers,
    query: query,
    hidden: hidden,
    tags: tags,
    produces: produces,
    extensions: extensions,
  );
}

void swaggerPost(
  String path, {
  ApiOperation? operation,
  List<ApiParam>? params,
  ApiBody? body,
  List<ApiResponse>? responses,
  List<ApiSecurity>? security,
  List<ApiHeader>? headers,
  List<ApiQuery>? query,
  List<ApiFileUpload>? fileUploads,
  bool hidden = false,
  List<String>? tags,
  List<String>? consumes,
  List<String>? produces,
  Map<String, dynamic>? extensions,
}) {
  swaggerRoute(
    method: 'POST',
    path: path,
    operation: operation,
    params: params,
    body: body,
    responses: responses,
    security: security,
    headers: headers,
    query: query,
    fileUploads: fileUploads,
    hidden: hidden,
    tags: tags,
    consumes: consumes,
    produces: produces,
    extensions: extensions,
  );
}

void swaggerPut(
  String path, {
  ApiOperation? operation,
  List<ApiParam>? params,
  ApiBody? body,
  List<ApiResponse>? responses,
  List<ApiSecurity>? security,
  List<ApiHeader>? headers,
  List<ApiQuery>? query,
  bool hidden = false,
  List<String>? tags,
  List<String>? consumes,
  List<String>? produces,
  Map<String, dynamic>? extensions,
}) {
  swaggerRoute(
    method: 'PUT',
    path: path,
    operation: operation,
    params: params,
    body: body,
    responses: responses,
    security: security,
    headers: headers,
    query: query,
    hidden: hidden,
    tags: tags,
    consumes: consumes,
    produces: produces,
    extensions: extensions,
  );
}

void swaggerPatch(
  String path, {
  ApiOperation? operation,
  List<ApiParam>? params,
  ApiBody? body,
  List<ApiResponse>? responses,
  List<ApiSecurity>? security,
  List<ApiHeader>? headers,
  List<ApiQuery>? query,
  bool hidden = false,
  List<String>? tags,
  List<String>? consumes,
  List<String>? produces,
  Map<String, dynamic>? extensions,
}) {
  swaggerRoute(
    method: 'PATCH',
    path: path,
    operation: operation,
    params: params,
    body: body,
    responses: responses,
    security: security,
    headers: headers,
    query: query,
    hidden: hidden,
    tags: tags,
    consumes: consumes,
    produces: produces,
    extensions: extensions,
  );
}

void swaggerDelete(
  String path, {
  ApiOperation? operation,
  List<ApiParam>? params,
  List<ApiResponse>? responses,
  List<ApiSecurity>? security,
  List<ApiHeader>? headers,
  bool hidden = false,
  List<String>? tags,
  List<String>? produces,
  Map<String, dynamic>? extensions,
}) {
  swaggerRoute(
    method: 'DELETE',
    path: path,
    operation: operation,
    params: params,
    responses: responses,
    security: security,
    headers: headers,
    hidden: hidden,
    tags: tags,
    produces: produces,
    extensions: extensions,
  );
}

void swaggerInfo(ApiInfo info) {
  SwaggerMetadata().setApiInfo(info);
}

void swaggerSchema(
  String name, {
  List<ApiProperty> properties = const [],
  String? description,
  String type = 'object',
  dynamic example,
  Map<String, dynamic> extensions = const {},
}) {
  SwaggerMetadata().addSchemaFromProperties(
    name,
    properties,
    description: description,
    type: type,
    example: example,
    extensions: extensions,
  );
}

void swaggerRawSchema(String name, Map<String, dynamic> schema) {
  SwaggerMetadata().addSchema(name, schema);
}

void swaggerServer(String url, {String? description}) {
  SwaggerMetadata().addServer(url, description: description);
}

void swaggerTag(
  String name, {
  String? description,
  String? externalDocsUrl,
  String? externalDocsDescription,
}) {
  SwaggerMetadata().addTag(
    name,
    description: description,
    externalDocsUrl: externalDocsUrl,
    externalDocsDescription: externalDocsDescription,
  );
}

void swaggerExternalDocs(String url, {String? description}) {
  SwaggerMetadata().setExternalDocs(url, description: description);
}

void swaggerAddBearerAuth({
  String name = 'bearerAuth',
  String? description,
  String bearerFormat = 'JWT',
}) {
  SwaggerMetadata().addBearerAuth(
    name: name,
    description: description,
    bearerFormat: bearerFormat,
  );
}

void swaggerAddBasicAuth({String name = 'basicAuth', String? description}) {
  SwaggerMetadata().addBasicAuth(name: name, description: description);
}

void swaggerAddApiKey({
  String name = 'apiKey',
  String headerName = 'X-API-Key',
  ApiKeyLocation location = ApiKeyLocation.header,
  String? description,
}) {
  SwaggerMetadata().addApiKey(
    name: name,
    headerName: headerName,
    location: location,
    description: description,
  );
}

void swaggerAddOAuth2({
  required String name,
  String? description,
  String? authorizationUrl,
  String? tokenUrl,
  String? refreshUrl,
  Map<String, String> scopes = const {},
}) {
  SwaggerMetadata().addOAuth2(
    name: name,
    description: description,
    authorizationUrl: authorizationUrl,
    tokenUrl: tokenUrl,
    refreshUrl: refreshUrl,
    scopes: scopes,
  );
}
