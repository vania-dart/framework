import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class Max extends ValidationRule {
  final num maxValue;
  Max({required this.maxValue, super.message});

  @override
  bool validate(value, data) {
    value = num.parse(value.toString());
    return value <= num.parse(maxValue.toString());
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be less than or equal $maxValue';
  }
}
