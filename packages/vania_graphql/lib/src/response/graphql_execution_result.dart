class VaniaGraphQLExecutionResult {
  const VaniaGraphQLExecutionResult({
    this.payload,
    this.stream,
    this.statusCode = 200,
  });

  final Map<String, dynamic>? payload;
  final Stream<Map<String, dynamic>>? stream;
  final int statusCode;

  bool get isStream => stream != null;
}
