import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsDate extends ValidationRule {
  IsDate({super.message});

  @override
  bool validate(value, data) {
    try {
      DateTime.parse(value.toString());
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The {field} must be a valid DateTime';
  }
}
