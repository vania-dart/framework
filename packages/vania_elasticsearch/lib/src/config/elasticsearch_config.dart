import 'package:vania/foundation.dart' show Config, env;

class ElasticsearchConfig {
  ElasticsearchConfig({
    List<Uri>? hosts,
    this.defaultIndex,
    this.indexPrefix = '',
    this.username,
    this.password,
    this.apiKey,
    this.bearerToken,
    this.headers = const {},
    this.maxRetries = 2,
    this.retryDelay = const Duration(milliseconds: 200),
    this.requestTimeout = const Duration(seconds: 30),
    this.connectTimeout = const Duration(seconds: 10),
    this.allowBadCertificates = false,
    this.retryStatusCodes = const [408, 429, 502, 503, 504],
    this.warmUp = false,
  }) : hosts = hosts ?? [Uri.parse('http://localhost:9200')];

  final List<Uri> hosts;
  final String? defaultIndex;
  final String indexPrefix;
  final String? username;
  final String? password;
  final String? apiKey;
  final String? bearerToken;
  final Map<String, String> headers;
  final int maxRetries;
  final Duration retryDelay;
  final Duration requestTimeout;
  final Duration connectTimeout;
  final bool allowBadCertificates;
  final List<int> retryStatusCodes;

  /// When `true`, [ElasticsearchServiceProvider.boot] issues a HEAD `/`
  /// against the cluster at startup and logs a warning on failure.
  /// Defaults to `false` — the client stays fully lazy.
  final bool warmUp;

  factory ElasticsearchConfig.fromApplication() {
    final config = Config().get('elasticsearch');
    final Map<String, dynamic> map = config is Map
        ? Map<String, dynamic>.from(config)
        : <String, dynamic>{};

    return ElasticsearchConfig(
      hosts: _hosts(map),
      defaultIndex: _stringOrNull(map, 'index', 'ELASTICSEARCH_INDEX'),
      indexPrefix: _string(
        map,
        'index_prefix',
        'ELASTICSEARCH_INDEX_PREFIX',
        '',
      ),
      username: _stringOrNull(map, 'username', 'ELASTICSEARCH_USERNAME'),
      password: _stringOrNull(map, 'password', 'ELASTICSEARCH_PASSWORD'),
      apiKey: _stringOrNull(map, 'api_key', 'ELASTICSEARCH_API_KEY'),
      bearerToken: _stringOrNull(
        map,
        'bearer_token',
        'ELASTICSEARCH_BEARER_TOKEN',
      ),
      headers: _headers(map['headers']),
      maxRetries: _int(map, 'max_retries', 'ELASTICSEARCH_MAX_RETRIES', 2),
      retryDelay: _duration(
        map,
        'retry_delay_ms',
        'ELASTICSEARCH_RETRY_DELAY_MS',
        const Duration(milliseconds: 200),
      ),
      requestTimeout: _duration(
        map,
        'request_timeout_ms',
        'ELASTICSEARCH_REQUEST_TIMEOUT_MS',
        const Duration(seconds: 30),
      ),
      connectTimeout: _duration(
        map,
        'connect_timeout_ms',
        'ELASTICSEARCH_CONNECT_TIMEOUT_MS',
        const Duration(seconds: 10),
      ),
      allowBadCertificates: _bool(
        map,
        'allow_bad_certificates',
        'ELASTICSEARCH_ALLOW_BAD_CERTIFICATES',
        false,
      ),
      retryStatusCodes: _retryStatuses(map['retry_status_codes']),
      warmUp: _bool(map, 'warm_up', 'ELASTICSEARCH_WARM_UP', false),
    );
  }

  String indexName(String index) {
    if (indexPrefix.isEmpty || index.startsWith(indexPrefix)) return index;
    return '$indexPrefix$index';
  }

  String requireIndex([String? index]) {
    final resolved = index ?? defaultIndex;
    if (resolved == null || resolved.trim().isEmpty) {
      throw ArgumentError('Elasticsearch index is required.');
    }
    return indexName(resolved);
  }

  ElasticsearchConfig copyWith({
    List<Uri>? hosts,
    String? defaultIndex,
    String? indexPrefix,
    String? username,
    String? password,
    String? apiKey,
    String? bearerToken,
    Map<String, String>? headers,
    int? maxRetries,
    Duration? retryDelay,
    Duration? requestTimeout,
    Duration? connectTimeout,
    bool? allowBadCertificates,
    List<int>? retryStatusCodes,
    bool? warmUp,
  }) {
    return ElasticsearchConfig(
      hosts: hosts ?? this.hosts,
      defaultIndex: defaultIndex ?? this.defaultIndex,
      indexPrefix: indexPrefix ?? this.indexPrefix,
      username: username ?? this.username,
      password: password ?? this.password,
      apiKey: apiKey ?? this.apiKey,
      bearerToken: bearerToken ?? this.bearerToken,
      headers: headers ?? this.headers,
      maxRetries: maxRetries ?? this.maxRetries,
      retryDelay: retryDelay ?? this.retryDelay,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      allowBadCertificates: allowBadCertificates ?? this.allowBadCertificates,
      retryStatusCodes: retryStatusCodes ?? this.retryStatusCodes,
      warmUp: warmUp ?? this.warmUp,
    );
  }

  static List<Uri> _hosts(Map<String, dynamic> map) {
    final value =
        map['hosts'] ?? map['host'] ?? env<String?>('ELASTICSEARCH_HOSTS');
    if (value is List) return value.map((host) => Uri.parse('$host')).toList();
    if (value is String && value.trim().isNotEmpty) {
      return value.split(',').map((host) => Uri.parse(host.trim())).toList();
    }
    return [Uri.parse('http://localhost:9200')];
  }

  static String _string(
    Map<String, dynamic> map,
    String key,
    String envKey,
    String defaultValue,
  ) {
    return _stringOrNull(map, key, envKey) ?? defaultValue;
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

  static int _int(
    Map<String, dynamic> map,
    String key,
    String envKey,
    int defaultValue,
  ) {
    final value = map[key] ?? env<String?>(envKey);
    if (value == null || value.toString().isEmpty) return defaultValue;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? defaultValue;
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

  static Duration _duration(
    Map<String, dynamic> map,
    String key,
    String envKey,
    Duration defaultValue,
  ) {
    final value = map[key] ?? env<String?>(envKey);
    if (value == null || value.toString().isEmpty) return defaultValue;
    if (value is Duration) return value;
    final milliseconds = value is int ? value : int.tryParse(value.toString());
    if (milliseconds == null) return defaultValue;
    return Duration(milliseconds: milliseconds);
  }

  static Map<String, String> _headers(dynamic value) {
    if (value is! Map) return const {};
    return value.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  static List<int> _retryStatuses(dynamic value) {
    if (value is List) {
      return value.map((status) => int.parse(status.toString())).toList();
    }
    return const [408, 429, 502, 503, 504];
  }
}
