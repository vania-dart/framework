import '../metadata/swagger_metadata.dart';
import '../annotations/annotations.dart';

class SwaggerGenerator {
  static final SwaggerGenerator _instance = SwaggerGenerator._internal();
  factory SwaggerGenerator() => _instance;
  SwaggerGenerator._internal();

  Map<String, dynamic> generate({String? serverUrl}) {
    final metadata = SwaggerMetadata();
    final info = metadata.apiInfo;

    final spec = <String, dynamic>{
      'openapi': '3.1.0',
      'info': _buildInfo(info),
      if (serverUrl != null || metadata.servers.isNotEmpty)
        'servers': _buildServers(metadata, serverUrl),
      'paths': <String, dynamic>{},
      'components': <String, dynamic>{
        'schemas': <String, dynamic>{},
        'securitySchemes': <String, dynamic>{},
      },
      if (metadata.externalDocs != null) 'externalDocs': metadata.externalDocs,
    };

    final paths = spec['paths'] as Map<String, dynamic>;
    final components = spec['components'] as Map<String, dynamic>;
    final schemas = components['schemas'] as Map<String, dynamic>;
    final securitySchemes =
        components['securitySchemes'] as Map<String, dynamic>;

    for (final schema in metadata.schemas.entries) {
      schemas[schema.key] = schema.value;
    }

    for (final scheme in metadata.securitySchemes) {
      final name = scheme['name'] as String? ?? 'bearerAuth';
      final schemeData = _normalizeSecurityScheme(scheme);
      securitySchemes[name] = schemeData;
    }

    final allTags = <String>{};

    for (final route in metadata.routes.values) {
      if (route.hidden) continue;

      final path = _normalizePath(route.path);
      final method = route.method.toLowerCase();

      if (!paths.containsKey(path)) {
        paths[path] = <String, dynamic>{};
      }

      final operation = _buildOperation(route, securitySchemes);
      (paths[path] as Map<String, dynamic>)[method] = operation;

      final tags = route.tags.isNotEmpty
          ? route.tags
          : route.operation?.tags ?? [];
      allTags.addAll(tags);
    }

    if (allTags.isNotEmpty) {
      spec['tags'] = allTags.map((tagName) {
        final tag = metadata.tags[tagName];
        if (tag == null) return {'name': tagName};
        return {
          'name': tag.name,
          if (tag.description != null) 'description': tag.description,
          if (tag.externalDocsUrl != null)
            'externalDocs': {
              'url': tag.externalDocsUrl,
              if (tag.externalDocsDescription != null)
                'description': tag.externalDocsDescription,
            },
        };
      }).toList();
    }

    if (components['schemas'].isEmpty) {
      components.remove('schemas');
    }
    if (components['securitySchemes'].isEmpty) {
      components.remove('securitySchemes');
    }
    if (components.isEmpty) {
      spec.remove('components');
    }

    return spec;
  }

  List<Map<String, dynamic>> _buildServers(
    SwaggerMetadata metadata,
    String? serverUrl,
  ) {
    final servers = <Map<String, dynamic>>[
      if (serverUrl != null)
        {'url': serverUrl, 'description': 'Development server'},
    ];

    for (final server in metadata.servers) {
      servers.add({
        'url': server.url,
        if (server.description != null) 'description': server.description,
        if (server.variables.isNotEmpty) 'variables': server.variables,
      });
    }

    return servers;
  }

  Map<String, dynamic> _normalizeSecurityScheme(Map<String, dynamic> scheme) {
    final schemeData = Map<String, dynamic>.from(scheme)..remove('name');
    final apiKeyName = schemeData.remove('nameValue');
    if (apiKeyName != null) schemeData['name'] = apiKeyName;
    return schemeData;
  }

  Map<String, dynamic> _buildInfo(ApiInfo? info) {
    return {
      'title': info?.title ?? 'API Documentation',
      'version': info?.version ?? '1.0.0',
      if (info?.description.isNotEmpty == true)
        'description': info!.description,
      if (info?.termsOfService != null) 'termsOfService': info!.termsOfService,
      if (info?.contact != null)
        'contact': {
          if (info!.contact!.name != null) 'name': info.contact!.name,
          if (info.contact!.email != null) 'email': info.contact!.email,
          if (info.contact!.url != null) 'url': info.contact!.url,
        },
      if (info?.license != null)
        'license': {
          'name': info!.license!.name,
          if (info.license!.url != null) 'url': info.license!.url,
        },
    };
  }

  Map<String, dynamic> _buildOperation(
    RouteMetadata route,
    Map<String, dynamic> securitySchemes,
  ) {
    final operation = <String, dynamic>{};

    final op = route.operation;
    if (op != null) {
      if (op.summary.isNotEmpty) operation['summary'] = op.summary;
      if (op.description.isNotEmpty) operation['description'] = op.description;
      if (op.operationId.isNotEmpty) operation['operationId'] = op.operationId;
      if (op.deprecated) operation['deprecated'] = true;
      if (op.externalDocsUrl != null) {
        operation['externalDocs'] = {
          'url': op.externalDocsUrl,
          if (op.externalDocsDescription != null)
            'description': op.externalDocsDescription,
        };
      }
      operation.addAll(op.extensions);
    }

    final tags = route.tags.isNotEmpty ? route.tags : op?.tags ?? [];
    if (tags.isNotEmpty) operation['tags'] = tags;

    final parameters = <Map<String, dynamic>>[];
    for (final param in route.params) {
      parameters.add(_buildParam(param));
    }

    for (final header in route.headers) {
      parameters.add(_buildHeader(header));
    }

    for (final query in route.query) {
      parameters.add(_buildQuery(query));
    }

    if (parameters.isNotEmpty) operation['parameters'] = parameters;

    if (route.body != null) {
      operation['requestBody'] = _buildRequestBody(route.body!, route.consumes);
    }

    if (route.fileUploads.isNotEmpty) {
      operation['requestBody'] = _buildFileUploadBody(route.fileUploads);
    }

    if (route.responses.isNotEmpty) {
      operation['responses'] = _buildResponses(route.responses, route.produces);
    } else {
      operation['responses'] = {
        '200': {'description': 'Success'},
      };
    }

    if (route.security.isNotEmpty) {
      operation['security'] = route.security
          .map((s) => {s.scheme: s.scopes})
          .toList();
    }

    operation.addAll(route.extensions);

    return operation;
  }

  Map<String, dynamic> _buildParam(ApiParam param) {
    return {
      'name': param.name,
      'in': _paramLocationToString(param.location),
      'required': param.location == ParamLocation.path ? true : param.required,
      if (param.description != null) 'description': param.description,
      'schema': _buildParameterSchema(
        type: param.schema,
        format: param.format,
        enumValues: param.enumValues,
        isArray: param.isArray,
      ),
      if (param.example != null) 'example': param.example,
      if (param.allowEmptyValue) 'allowEmptyValue': true,
      if (param.deprecated) 'deprecated': true,
      if (param.style != null) 'style': param.style,
      if (param.explode != null) 'explode': param.explode,
    };
  }

  Map<String, dynamic> _buildHeader(ApiHeader header) {
    return {
      'name': header.name,
      'in': 'header',
      'required': header.required,
      if (header.description != null) 'description': header.description,
      'schema': _buildParameterSchema(
        type: header.schema,
        format: header.format,
        enumValues: header.enumValues,
        isArray: header.isArray,
      ),
      if (header.example != null) 'example': header.example,
    };
  }

  Map<String, dynamic> _buildQuery(ApiQuery query) {
    return {
      'name': query.name,
      'in': 'query',
      'required': query.required,
      if (query.description != null) 'description': query.description,
      'schema': _buildParameterSchema(
        type: query.schema,
        format: query.format,
        enumValues: query.enumValues,
        isArray: query.isArray,
      ),
      if (query.example != null) 'example': query.example,
      if (query.allowEmptyValue) 'allowEmptyValue': true,
      if (query.deprecated) 'deprecated': true,
    };
  }

  Map<String, dynamic> _buildParameterSchema({
    String? type,
    String? format,
    List<String>? enumValues,
    bool isArray = false,
  }) {
    final schema = <String, dynamic>{};
    schema['type'] = type ?? 'string';
    if (format != null) schema['format'] = format;
    if (enumValues != null) schema['enum'] = enumValues;
    if (!isArray) return schema;
    return {'type': 'array', 'items': schema};
  }

  Map<String, dynamic> _buildRequestBody(ApiBody body, List<String> consumes) {
    final requestBody = <String, dynamic>{'required': body.required};

    if (body.description.isNotEmpty) {
      requestBody['description'] = body.description;
    }

    final contentTypes = _contentTypes(
      body.contentTypes,
      consumes,
      body.contentType,
    );
    requestBody['content'] = _buildContent(
      contentTypes,
      _buildSchema(
        body.schema,
        schemaRef: body.schemaRef,
        rawSchema: body.rawSchema,
      ),
      example: body.example,
      examples: body.examples,
    );

    return requestBody;
  }

  Map<String, dynamic> _buildFileUploadBody(List<ApiFileUpload> files) {
    final requestBody = <String, dynamic>{
      'required': true,
      'content': <String, dynamic>{},
    };

    final content = requestBody['content'] as Map<String, dynamic>;

    if (files.length == 1) {
      final file = files.first;
      content['multipart/form-data'] = {
        'schema': {
          'type': 'object',
          'properties': {
            file.name: {
              'type': 'string',
              'format': 'binary',
              if (file.description.isNotEmpty) 'description': file.description,
            },
          },
          'required': file.required ? [file.name] : [],
        },
      };
    } else {
      final properties = <String, dynamic>{};
      final required = <String>[];

      for (final file in files) {
        properties[file.name] = {
          'type': 'string',
          'format': 'binary',
          if (file.description.isNotEmpty) 'description': file.description,
        };
        if (file.required) required.add(file.name);
      }

      content['multipart/form-data'] = {
        'schema': {
          'type': 'object',
          'properties': properties,
          if (required.isNotEmpty) 'required': required,
        },
      };
    }

    return requestBody;
  }

  Map<String, dynamic> _buildResponses(
    List<ApiResponse> responses,
    List<String> produces,
  ) {
    final result = <String, dynamic>{};

    for (final response in responses) {
      final statusCode = response.statusCode.toString();
      final responseObj = <String, dynamic>{
        'description': response.description.isNotEmpty
            ? response.description
            : _defaultResponseDescription(response.statusCode),
      };

      if (response.headers != null && response.headers!.isNotEmpty) {
        responseObj['headers'] = response.headers!.map(
          (key, value) => MapEntry(key, {
            'schema': {'type': 'string'},
            'description': value,
          }),
        );
      }

      final schema = _buildResponseSchema(response);
      if (schema != null) {
        responseObj['content'] = _buildContent(
          _contentTypes(response.contentTypes, produces, 'application/json'),
          schema,
          example: response.example,
          examples: response.examples,
        );
      } else if (response.example != null) {
        responseObj['content'] = _buildContent(
          _contentTypes(response.contentTypes, produces, 'application/json'),
          {'type': 'object'},
          example: response.example,
          examples: response.examples,
        );
      }

      result[statusCode] = responseObj;
    }

    return result;
  }

  Map<String, dynamic>? _buildResponseSchema(ApiResponse response) {
    if (response.oneOf.isNotEmpty) {
      return {'oneOf': response.oneOf.map(_buildSchemaFromType).toList()};
    }
    if (response.anyOf.isNotEmpty) {
      return {'anyOf': response.anyOf.map(_buildSchemaFromType).toList()};
    }
    if (response.allOf.isNotEmpty) {
      return {'allOf': response.allOf.map(_buildSchemaFromType).toList()};
    }
    if (response.schema != null ||
        response.schemaRef != null ||
        response.rawSchema != null) {
      return _buildSchema(
        response.schema,
        schemaRef: response.schemaRef,
        rawSchema: response.rawSchema,
      );
    }
    return null;
  }

  Map<String, dynamic> _buildContent(
    List<String> contentTypes,
    Map<String, dynamic> schema, {
    dynamic example,
    Map<String, dynamic>? examples,
  }) {
    final content = <String, dynamic>{};
    for (final contentType in contentTypes) {
      final mediaType = <String, dynamic>{'schema': schema};
      if (example != null) mediaType['example'] = example;
      if (examples != null) mediaType['examples'] = examples;
      content[contentType] = mediaType;
    }
    return content;
  }

  List<String> _contentTypes(
    List<String> specific,
    List<String> routeLevel,
    String? fallback,
  ) {
    if (specific.isNotEmpty) return specific;
    if (routeLevel.isNotEmpty) return routeLevel;
    return [fallback ?? 'application/json'];
  }

  Map<String, dynamic> _buildSchema(
    Type? type, {
    String? schemaRef,
    Map<String, dynamic>? rawSchema,
  }) {
    if (rawSchema != null) return Map<String, dynamic>.from(rawSchema);
    if (schemaRef != null) {
      return {
        '\$ref': schemaRef.startsWith('#/')
            ? schemaRef
            : '#/components/schemas/$schemaRef',
      };
    }
    return _buildSchemaFromType(type);
  }

  Map<String, dynamic> _buildSchemaFromType(Type? type) {
    if (type == null) {
      return {'type': 'object'};
    }

    final typeName = type.toString();

    return switch (typeName) {
      'String' => {'type': 'string'},
      'int' => {'type': 'integer'},
      'double' || 'num' => {'type': 'number'},
      'bool' => {'type': 'boolean'},
      'List' || 'List<dynamic>' => {
        'type': 'array',
        'items': {'type': 'object'},
      },
      _ => {'\$ref': '#/components/schemas/$typeName'},
    };
  }

  String _normalizePath(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return normalized.replaceAllMapped(
      RegExp(r':([A-Za-z_][A-Za-z0-9_]*)'),
      (match) => '{${match.group(1)}}',
    );
  }

  String _paramLocationToString(ParamLocation location) {
    return switch (location) {
      ParamLocation.path => 'path',
      ParamLocation.query => 'query',
      ParamLocation.header => 'header',
      ParamLocation.cookie => 'cookie',
    };
  }

  String _defaultResponseDescription(int statusCode) {
    return switch (statusCode) {
      200 => 'Success',
      201 => 'Created',
      204 => 'No Content',
      400 => 'Bad Request',
      401 => 'Unauthorized',
      403 => 'Forbidden',
      404 => 'Not Found',
      422 => 'Unprocessable Entity',
      500 => 'Internal Server Error',
      _ => 'Response $statusCode',
    };
  }
}
