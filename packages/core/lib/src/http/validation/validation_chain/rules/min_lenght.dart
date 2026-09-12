import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class MinLength extends ValidationRule {
  int minLength;
  MinLength({required this.minLength, super.message});

  @override
  bool validate(value, data) {
    value = value.toString().length;
    return value.toString().length >= minLength;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The {field} should not be less than $minLength character';
  }
}
