class CteException implements Exception {
  final String message;

  final String? cteName;

  CteException(this.message, [this.cteName]);

  @override
  String toString() =>
      'CteException: $message${cteName != null ? ' (CTE: $cteName)' : ''}';
}
