import 'package:vania/foundation.dart' show Config, env;

/// Configuration for the Swagger UI + spec route.
class SwaggerConfig {
  const SwaggerConfig({
    this.enabled = true,
    this.basePath = '/docs',
    this.title = 'API Documentation',
    this.description = '',
    this.version = '1.0.0',
    this.serverUrl,
    this.responseHeaders = const {},
    this.corsEnabled = true,
  });

  /// When `false`, the provider does NOT register the doc routes.
  final bool enabled;

  /// The base HTTP path the docs are served under. `/docs` becomes
  /// `GET /docs`, `GET /docs/swagger.json`, `GET /docs/swagger.yaml`.
  final String basePath;

  final String title;
  final String description;
  final String version;

  /// Override the OpenAPI `servers[0].url`. When `null` the incoming
  /// request's scheme + host + port is used at spec generation time.
  final String? serverUrl;

  final Map<String, String> responseHeaders;

  /// Emit `Access-Control-Allow-Origin: *` on spec/UI responses. Handy for
  /// mounting a separate frontend that fetches the spec cross-origin.
  final bool corsEnabled;

  factory SwaggerConfig.fromApplication() {
    final config = Config().get('swagger');
    final Map<String, dynamic> map = config is Map
        ? Map<String, dynamic>.from(config)
        : <String, dynamic>{};

    // Off by default in production: the docs describe every route,
    // parameter and schema the API exposes. Set `SWAGGER_ENABLED=true`
    // (or `swagger.enabled` in config) to serve them there deliberately,
    // ideally alongside `middleware`.
    final isProduction = env<String>('APP_ENV', 'production') == 'production';

    return SwaggerConfig(
      enabled: _bool(map, 'enabled', 'SWAGGER_ENABLED', !isProduction),
      basePath: _string(map, 'base_path', 'SWAGGER_BASE_PATH', '/docs'),
      title: _string(map, 'title', 'SWAGGER_TITLE', 'API Documentation'),
      description: _string(map, 'description', 'SWAGGER_DESCRIPTION', ''),
      version: _string(map, 'version', 'SWAGGER_VERSION', '1.0.0'),
      serverUrl: _stringOrNull(map, 'server_url', 'SWAGGER_SERVER_URL'),
      corsEnabled: _bool(map, 'cors', 'SWAGGER_CORS', true),
    );
  }

  /// Returns the base path with no trailing slash. Guards against the
  /// `substring(0, -1)` crash the earlier implementation had.
  String normalizedBasePath() {
    var p = basePath.trim();
    if (p.isEmpty) return '/docs';
    if (!p.startsWith('/')) p = '/$p';
    if (p.endsWith('/') && p.length > 1) p = p.substring(0, p.length - 1);
    return p;
  }

  static String _string(
    Map<String, dynamic> map,
    String key,
    String envKey,
    String defaultValue,
  ) {
    final value = map[key] ?? env<String?>(envKey);
    if (value == null || value.toString().isEmpty) return defaultValue;
    return value.toString();
  }

  static String? _stringOrNull(
    Map<String, dynamic> map,
    String key,
    String envKey,
  ) {
    final value = map[key] ?? env<String?>(envKey);
    if (value == null || value.toString().isEmpty) return null;
    return value.toString();
  }

  static bool _bool(
    Map<String, dynamic> map,
    String key,
    String envKey,
    bool defaultValue,
  ) {
    final value = map[key] ?? env<String?>(envKey);
    if (value == null || value.toString().isEmpty) return defaultValue;
    if (value is bool) return value;
    return value.toString().toLowerCase() == 'true';
  }
}
