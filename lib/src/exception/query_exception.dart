class QueryException implements Exception {
  final String? cause;
  QueryException([
    this.cause,
  ]);
}
