import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsNumeric extends ValidationRule {
  IsNumeric({super.message});

  @override
  bool validate(value, data) {
    try {
      num.parse(value.toString());
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be a number';
  }
}
