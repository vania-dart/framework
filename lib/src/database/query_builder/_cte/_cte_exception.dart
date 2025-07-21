class CteException implements Exception {
  final String message;

  final String? cteName;

  CteException(this.message, [this.cteName]);
}
