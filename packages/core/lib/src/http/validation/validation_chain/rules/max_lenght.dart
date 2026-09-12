import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class MaxLength extends ValidationRule {
  int maxLength;
  MaxLength({required this.maxLength, super.message});

  @override
  bool validate(value, data) {
    value = value.toString().length;
    return value.toString().length <= maxLength;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The {field} should not be greater than $maxLength character';
  }
}
