class ElasticsearchRequest {
  const ElasticsearchRequest({
    required this.method,
    required this.path,
    this.queryParameters = const {},
    this.body,
    this.headers = const {},
    this.ndjson = false,
  });

  final String method;
  final String path;
  final Map<String, dynamic> queryParameters;
  final dynamic body;
  final Map<String, String> headers;
  final bool ndjson;

  ElasticsearchRequest copyWith({
    String? method,
    String? path,
    Map<String, dynamic>? queryParameters,
    dynamic body,
    Map<String, String>? headers,
    bool? ndjson,
  }) {
    return ElasticsearchRequest(
      method: method ?? this.method,
      path: path ?? this.path,
      queryParameters: queryParameters ?? this.queryParameters,
      body: body ?? this.body,
      headers: headers ?? this.headers,
      ndjson: ndjson ?? this.ndjson,
    );
  }
}
