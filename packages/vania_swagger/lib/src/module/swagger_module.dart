import '../annotations/annotations.dart';
import '../metadata/swagger_metadata.dart';

/// AOT-safe helpers for populating the [SwaggerMetadata] singleton.
///
/// Use [registerRoute] and [registerModel] to describe your API surface
/// without runtime reflection.
///
/// ```dart
/// SwaggerModule.registerRoute(
///   method: 'GET',
///   path: '/users',
///   operation: const ApiOperation(summary: 'List users'),
///   tags: ['Users'],
///   responses: [const ApiOkResponse(schemaRef: 'UserList')],
/// );
/// ```
class SwaggerModule {
  const SwaggerModule._();

  /// Register a single route in the Swagger spec.
  static void registerRoute({
    required String method,
    required String path,
    ApiOperation? operation,
    List<ApiParam> params = const [],
    List<ApiQuery> query = const [],
    List<ApiHeader> headers = const [],
    ApiBody? body,
    List<ApiResponse> responses = const [],
    List<ApiSecurity> security = const [],
    List<ApiFileUpload> fileUploads = const [],
    bool hidden = false,
    List<String> tags = const [],
    List<String> consumes = const [],
    List<String> produces = const [],
  }) {
    SwaggerMetadata().addRoute(
      RouteMetadata(
        method: method.toUpperCase(),
        path: path,
        operation: operation,
        params: params,
        query: query,
        headers: headers,
        body: body,
        responses: responses,
        security: security,
        fileUploads: fileUploads,
        hidden: hidden,
        tags: tags,
        consumes: consumes,
        produces: produces,
      ),
    );
  }

  /// Register a component schema (DTO / model).
  static void registerModel(
    String name, {
    required List<ApiProperty> properties,
    String? description,
    String type = 'object',
    dynamic example,
  }) {
    SwaggerMetadata().addSchemaFromProperties(
      name,
      properties,
      description: description,
      type: type,
      example: example,
    );
  }
}
