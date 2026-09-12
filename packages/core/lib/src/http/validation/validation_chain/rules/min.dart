import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class Min extends ValidationRule {
  final num minValue;
  Min({required this.minValue, super.message});

  @override
  bool validate(value, data) {
    value = num.parse(value.toString());
    return value >= num.parse(minValue.toString());
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field be greater than or equal $minValue';
  }
}
