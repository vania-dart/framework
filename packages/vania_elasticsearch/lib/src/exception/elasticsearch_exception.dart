class ElasticsearchException implements Exception {
  const ElasticsearchException(
    this.message, {
    this.statusCode,
    this.body,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final dynamic body;
  final Object? cause;

  @override
  String toString() {
    if (statusCode == null) return 'ElasticsearchException: $message';
    return 'ElasticsearchException($statusCode): $message';
  }
}
