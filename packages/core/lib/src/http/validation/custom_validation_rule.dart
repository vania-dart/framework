class CustomValidationRule {
  final String ruleName;
  final String message;
  final Future<bool> Function(Map<String, dynamic>, dynamic, String?) fn;

  CustomValidationRule({
    required this.ruleName,
    required this.message,
    required this.fn,
  });
}
