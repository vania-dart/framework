import 'package:vaniaFramework/src/http/validation/validation_chain/validation_rule.dart';

class Between extends ValidationRule {
  final num lowerBoundary;
  final num higherBoundary;
  Between(
      {required this.lowerBoundary,
      required this.higherBoundary,
      super.message});

  @override
  bool validate(value, data) {
    value = num.parse(value.toString());
    return value >= lowerBoundary && value <= higherBoundary;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field should be between $lowerBoundary and $higherBoundary';
  }
}
