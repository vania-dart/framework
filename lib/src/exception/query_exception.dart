class QueryException implements Exception {
  final String sql;
  final dynamic bindings;
  final dynamic cause;
  QueryException([
    this.sql = 'QueryException',
    this.bindings,
    this.cause,
  ]);
}
