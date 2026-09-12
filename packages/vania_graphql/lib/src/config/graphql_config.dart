import 'package:vania/foundation.dart' show Config, env;

class GraphQLConfig {
  const GraphQLConfig({
    this.endpoint = '/graphql',
    this.routeEnabled = true,
    this.graphiqlEnabled = true,
    this.introspectionEnabled = true,
    this.allowGet = true,
    this.allowPost = true,
    this.allowSubscriptions = true,
    this.exposeExceptionDetails = false,
    this.maxQueryLength,
    this.maxQueryDepth,
    this.errorStatusCode = 200,
    this.executionTimeout,
    this.responseHeaders = const {},
    this.subscriptionsOverWebSocket = true,
    this.subscriptionsEndpoint = '/graphql/ws',
    this.keepAliveInterval = const Duration(seconds: 30),
  });

  final String endpoint;
  final bool routeEnabled;
  final bool graphiqlEnabled;
  final bool introspectionEnabled;
  final bool allowGet;
  final bool allowPost;
  final bool allowSubscriptions;
  final bool exposeExceptionDetails;
  final int? maxQueryLength;

  /// Maximum selection nesting allowed in a single operation.
  ///
  /// Defaults to 15, which is well past any hand-written query but stops
  /// the recursive-expansion DoS that a cyclic schema allows. Set to
  /// `null` to disable the check.
  final int? maxQueryDepth;
  final int errorStatusCode;
  final Duration? executionTimeout;
  final Map<String, String> responseHeaders;

  /// When `true` and [allowSubscriptions] is also true, the provider
  /// installs a `graphql-ws` sub-protocol handler on the app's
  /// [WebSocketUpgradeDispatcher] under [subscriptionsEndpoint]. Non-
  /// matching upgrades pass through to any pre-existing handler
  /// (e.g. `vania_websocket`), so both can coexist on the same port.
  final bool subscriptionsOverWebSocket;
  final String subscriptionsEndpoint;
  final Duration keepAliveInterval;

  factory GraphQLConfig.fromApplication() {
    final config = Config().get('graphql');
    final Map<String, dynamic> map = config is Map
        ? Map<String, dynamic>.from(config)
        : <String, dynamic>{};

    // Introspection and the GraphiQL IDE default off in production:
    // introspection publishes the complete schema and GraphiQL ships a
    // query console alongside it. Set the env vars explicitly to serve
    // them in production on purpose.
    final isProduction = env<String>('APP_ENV', 'production') == 'production';

    return GraphQLConfig(
      endpoint: _string(map, 'endpoint', 'GRAPHQL_ENDPOINT', '/graphql'),
      routeEnabled: _bool(map, 'route_enabled', 'GRAPHQL_ROUTE_ENABLED', true),
      graphiqlEnabled: _bool(
        map,
        'graphiql_enabled',
        'GRAPHQL_GRAPHIQL_ENABLED',
        !isProduction,
      ),
      introspectionEnabled: _bool(
        map,
        'introspection_enabled',
        'GRAPHQL_INTROSPECTION_ENABLED',
        !isProduction,
      ),
      allowGet: _bool(map, 'allow_get', 'GRAPHQL_ALLOW_GET', true),
      allowPost: _bool(map, 'allow_post', 'GRAPHQL_ALLOW_POST', true),
      allowSubscriptions: _bool(
        map,
        'allow_subscriptions',
        'GRAPHQL_ALLOW_SUBSCRIPTIONS',
        true,
      ),
      exposeExceptionDetails: _bool(
        map,
        'debug',
        'GRAPHQL_DEBUG',
        env<String?>('APP_ENV') == 'development',
      ),
      maxQueryLength: _intOrNull(
        map,
        'max_query_length',
        'GRAPHQL_MAX_QUERY_LENGTH',
      ),
      maxQueryDepth:
          _intOrNull(map, 'max_query_depth', 'GRAPHQL_MAX_QUERY_DEPTH') ?? 15,
      errorStatusCode: _int(
        map,
        'error_status_code',
        'GRAPHQL_ERROR_STATUS',
        200,
      ),
      executionTimeout: _durationOrNull(
        map,
        'execution_timeout_ms',
        'GRAPHQL_EXECUTION_TIMEOUT_MS',
      ),
      responseHeaders: _headers(map['response_headers']),
      subscriptionsOverWebSocket: _bool(
        map,
        'subscriptions_over_websocket',
        'GRAPHQL_SUBSCRIPTIONS_OVER_WS',
        true,
      ),
      subscriptionsEndpoint: _string(
        map,
        'subscriptions_endpoint',
        'GRAPHQL_SUBSCRIPTIONS_ENDPOINT',
        '/graphql/ws',
      ),
      keepAliveInterval:
          _durationOrNull(
            map,
            'keep_alive_interval_ms',
            'GRAPHQL_KEEP_ALIVE_MS',
          ) ??
          const Duration(seconds: 30),
    );
  }

  GraphQLConfig copyWith({
    String? endpoint,
    bool? routeEnabled,
    bool? graphiqlEnabled,
    bool? introspectionEnabled,
    bool? allowGet,
    bool? allowPost,
    bool? allowSubscriptions,
    bool? exposeExceptionDetails,
    int? maxQueryLength,
    int? errorStatusCode,
    Duration? executionTimeout,
    Map<String, String>? responseHeaders,
    bool? subscriptionsOverWebSocket,
    String? subscriptionsEndpoint,
    Duration? keepAliveInterval,
  }) {
    return GraphQLConfig(
      endpoint: endpoint ?? this.endpoint,
      routeEnabled: routeEnabled ?? this.routeEnabled,
      graphiqlEnabled: graphiqlEnabled ?? this.graphiqlEnabled,
      introspectionEnabled: introspectionEnabled ?? this.introspectionEnabled,
      allowGet: allowGet ?? this.allowGet,
      allowPost: allowPost ?? this.allowPost,
      allowSubscriptions: allowSubscriptions ?? this.allowSubscriptions,
      exposeExceptionDetails:
          exposeExceptionDetails ?? this.exposeExceptionDetails,
      maxQueryLength: maxQueryLength ?? this.maxQueryLength,
      errorStatusCode: errorStatusCode ?? this.errorStatusCode,
      executionTimeout: executionTimeout ?? this.executionTimeout,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      subscriptionsOverWebSocket:
          subscriptionsOverWebSocket ?? this.subscriptionsOverWebSocket,
      subscriptionsEndpoint:
          subscriptionsEndpoint ?? this.subscriptionsEndpoint,
      keepAliveInterval: keepAliveInterval ?? this.keepAliveInterval,
    );
  }

  static String _string(
    Map<String, dynamic> map,
    String key,
    String envKey,
    String defaultValue,
  ) {
    final value = map[key] ?? env<String?>(envKey);
    if (value == null) return defaultValue;
    return value.toString();
  }

  static bool _bool(
    Map<String, dynamic> map,
    String key,
    String envKey,
    bool defaultValue,
  ) {
    final value = map[key] ?? env<String?>(envKey);
    if (value == null) return defaultValue;
    if (value is bool) return value;
    return value.toString().toLowerCase() == 'true';
  }

  static int _int(
    Map<String, dynamic> map,
    String key,
    String envKey,
    int defaultValue,
  ) {
    return _intOrNull(map, key, envKey) ?? defaultValue;
  }

  static int? _intOrNull(Map<String, dynamic> map, String key, String envKey) {
    final value = map[key] ?? env<String?>(envKey);
    if (value == null || value.toString().isEmpty) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static Duration? _durationOrNull(
    Map<String, dynamic> map,
    String key,
    String envKey,
  ) {
    final milliseconds = _intOrNull(map, key, envKey);
    if (milliseconds == null) return null;
    return Duration(milliseconds: milliseconds);
  }

  static Map<String, String> _headers(dynamic value) {
    if (value is! Map) return const {};
    return value.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }
}
