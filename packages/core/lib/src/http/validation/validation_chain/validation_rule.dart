abstract class ValidationRule {
  final String? message;
  ValidationRule({this.message});
  bool validate(dynamic value, Map<String, dynamic> data);
  String get errorMessage => message ?? getDefaultErrorMessage('');
  String getDefaultErrorMessage(String field);
}
