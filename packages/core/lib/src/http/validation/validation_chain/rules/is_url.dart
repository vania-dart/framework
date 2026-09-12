import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsURL extends ValidationRule {
  IsURL({super.message});

  @override
  bool validate(value, data) {
    try {
      Uri? uri = Uri.tryParse(value);
      return uri != null && uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The {field} must be a valid UUID';
  }
}
