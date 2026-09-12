import '../annotations/annotations.dart';

class RouteMetadata {
  final String method;
  final String path;
  final ApiOperation? operation;
  final List<ApiParam> params;
  final ApiBody? body;
  final List<ApiResponse> responses;
  final List<ApiSecurity> security;
  final List<ApiHeader> headers;
  final List<ApiQuery> query;
  final List<ApiFileUpload> fileUploads;
  final bool hidden;
  final List<String> tags;
  final List<String> consumes;
  final List<String> produces;
  final Map<String, dynamic> extensions;

  const RouteMetadata({
    required this.method,
    required this.path,
    this.operation,
    this.params = const [],
    this.body,
    this.responses = const [],
    this.security = const [],
    this.headers = const [],
    this.query = const [],
    this.fileUploads = const [],
    this.hidden = false,
    this.tags = const [],
    this.consumes = const [],
    this.produces = const [],
    this.extensions = const {},
  });
}

class SwaggerServer {
  final String url;
  final String? description;
  final Map<String, dynamic> variables;

  const SwaggerServer({
    required this.url,
    this.description,
    this.variables = const {},
  });
}

class SwaggerTag {
  final String name;
  final String? description;
  final String? externalDocsUrl;
  final String? externalDocsDescription;

  const SwaggerTag({
    required this.name,
    this.description,
    this.externalDocsUrl,
    this.externalDocsDescription,
  });
}

class SwaggerMetadata {
  static final SwaggerMetadata _instance = SwaggerMetadata._internal();
  factory SwaggerMetadata() => _instance;
  SwaggerMetadata._internal();

  ApiInfo? _apiInfo;
  final Map<String, RouteMetadata> _routes = {};
  final Map<String, Map<String, dynamic>> _schemas = {};
  final Map<String, Map<String, dynamic>> _securitySchemes = {};
  final List<SwaggerServer> _servers = [];
  final Map<String, SwaggerTag> _tags = {};
  String? _externalDocsUrl;
  String? _externalDocsDescription;

  ApiInfo? get apiInfo => _apiInfo;

  void setApiInfo(ApiInfo info) {
    _apiInfo = info;
  }

  void addRoute(RouteMetadata metadata) {
    final key = '${metadata.method}:${metadata.path}';
    _routes[key] = metadata;
  }

  RouteMetadata? getRoute(String method, String path) {
    return _routes['$method:$path'];
  }

  Map<String, RouteMetadata> get routes => Map.unmodifiable(_routes);

  void addSchema(String name, Map<String, dynamic> schema) {
    _schemas[name] = schema;
  }

  Map<String, Map<String, dynamic>> get schemas => Map.unmodifiable(_schemas);

  void addSecurityScheme(Map<String, dynamic> scheme) {
    final name = scheme['name'] as String? ?? 'default';
    final schemeData = Map<String, dynamic>.from(scheme);
    _securitySchemes[name] = schemeData;
  }

  List<Map<String, dynamic>> get securitySchemes =>
      List.unmodifiable(_securitySchemes.values);

  void addBearerAuth({
    String name = 'bearerAuth',
    String? description,
    String bearerFormat = 'JWT',
  }) {
    final scheme = <String, dynamic>{
      'name': name,
      'type': 'http',
      'scheme': 'bearer',
      'bearerFormat': bearerFormat,
    };
    if (description != null) scheme['description'] = description;
    addSecurityScheme(scheme);
  }

  void addBasicAuth({String name = 'basicAuth', String? description}) {
    final scheme = <String, dynamic>{
      'name': name,
      'type': 'http',
      'scheme': 'basic',
    };
    if (description != null) scheme['description'] = description;
    addSecurityScheme(scheme);
  }

  void addApiKey({
    String name = 'apiKey',
    String headerName = 'X-API-Key',
    ApiKeyLocation location = ApiKeyLocation.header,
    String? description,
  }) {
    final scheme = <String, dynamic>{
      'name': name,
      'type': 'apiKey',
      'in': _apiKeyLocation(location),
      'nameValue': headerName,
    };
    if (description != null) scheme['description'] = description;
    addSecurityScheme(scheme);
  }

  void addOAuth2({
    required String name,
    String? description,
    String? authorizationUrl,
    String? tokenUrl,
    String? refreshUrl,
    Map<String, String> scopes = const {},
  }) {
    final flow = <String, dynamic>{'scopes': scopes};
    if (authorizationUrl != null) flow['authorizationUrl'] = authorizationUrl;
    if (tokenUrl != null) flow['tokenUrl'] = tokenUrl;
    if (refreshUrl != null) flow['refreshUrl'] = refreshUrl;

    final scheme = <String, dynamic>{
      'name': name,
      'type': 'oauth2',
      'flows': {'authorizationCode': flow},
    };
    if (description != null) scheme['description'] = description;
    addSecurityScheme(scheme);
  }

  void addSchemaFromProperties(
    String name,
    List<ApiProperty> properties, {
    String? description,
    String type = 'object',
    dynamic example,
    Map<String, dynamic> extensions = const {},
  }) {
    final schema = <String, dynamic>{'type': type, ...extensions};
    if (description != null && description.isNotEmpty) {
      schema['description'] = description;
    }
    if (example != null) schema['example'] = example;

    final required = <String>[];
    final propertyMap = <String, dynamic>{};
    for (final property in properties) {
      propertyMap[property.name] = _propertyToSchema(property);
      if (property.required) required.add(property.name);
    }

    if (propertyMap.isNotEmpty) schema['properties'] = propertyMap;
    if (required.isNotEmpty) schema['required'] = required;

    addSchema(name, schema);
  }

  void addServer(String url, {String? description}) {
    _servers.add(SwaggerServer(url: url, description: description));
  }

  List<SwaggerServer> get servers => List.unmodifiable(_servers);

  void addTag(
    String name, {
    String? description,
    String? externalDocsUrl,
    String? externalDocsDescription,
  }) {
    _tags[name] = SwaggerTag(
      name: name,
      description: description,
      externalDocsUrl: externalDocsUrl,
      externalDocsDescription: externalDocsDescription,
    );
  }

  Map<String, SwaggerTag> get tags => Map.unmodifiable(_tags);

  void setExternalDocs(String url, {String? description}) {
    _externalDocsUrl = url;
    _externalDocsDescription = description;
  }

  Map<String, dynamic>? get externalDocs {
    final url = _externalDocsUrl;
    if (url == null) return null;
    return {
      'url': url,
      if (_externalDocsDescription != null)
        'description': _externalDocsDescription,
    };
  }

  void clear() {
    _apiInfo = null;
    _routes.clear();
    _schemas.clear();
    _securitySchemes.clear();
    _servers.clear();
    _tags.clear();
    _externalDocsUrl = null;
    _externalDocsDescription = null;
  }

  String _apiKeyLocation(ApiKeyLocation location) {
    return switch (location) {
      ApiKeyLocation.query => 'query',
      ApiKeyLocation.header => 'header',
      ApiKeyLocation.cookie => 'cookie',
    };
  }

  Map<String, dynamic> _propertyToSchema(ApiProperty property) {
    final schema = <String, dynamic>{};

    if (property.ref != null) {
      schema['\$ref'] = property.ref!.startsWith('#/')
          ? property.ref
          : '#/components/schemas/${property.ref}';
    } else {
      schema['type'] = property.type ?? 'string';
    }

    if (property.format != null) schema['format'] = property.format;
    if (property.description != null) {
      schema['description'] = property.description;
    }
    if (property.example != null) schema['example'] = property.example;
    if (property.examples != null) schema['examples'] = property.examples;
    if (property.enumValues != null) schema['enum'] = property.enumValues;
    if (property.nullable) schema['nullable'] = true;
    if (property.deprecated) schema['deprecated'] = true;
    if (property.readOnly) schema['readOnly'] = true;
    if (property.writeOnly) schema['writeOnly'] = true;
    if (property.defaultValue != null) {
      schema['default'] = property.defaultValue;
    }
    if (property.minimum != null) schema['minimum'] = property.minimum;
    if (property.maximum != null) schema['maximum'] = property.maximum;
    if (property.minLength != null) schema['minLength'] = property.minLength;
    if (property.maxLength != null) schema['maxLength'] = property.maxLength;
    if (property.pattern != null) schema['pattern'] = property.pattern;
    schema.addAll(property.extensions);

    if (!property.isArray) return schema;

    final itemSchema = property.items == null
        ? (Map<String, dynamic>.from(schema)..remove('description'))
        : _propertyToSchema(property.items!);

    return {
      'type': 'array',
      'items': itemSchema,
      if (property.description != null) 'description': property.description,
      if (property.example != null) 'example': property.example,
      if (property.nullable) 'nullable': true,
      ...property.extensions,
    };
  }
}
