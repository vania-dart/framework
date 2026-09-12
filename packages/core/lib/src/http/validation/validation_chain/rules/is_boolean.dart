import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsBoolean extends ValidationRule {
  IsBoolean({super.message});

  @override
  bool validate(value, data) {
    return value is bool;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be a boolean';
  }
}
