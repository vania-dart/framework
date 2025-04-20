class DatabaseException implements Exception {
  final String message;
  final dynamic cause;

  DatabaseException(this.message, [this.cause]);

  @override
  String toString() =>
      'DatabaseException: $message${cause != null ? '\nCause: $cause' : ''}';
}
