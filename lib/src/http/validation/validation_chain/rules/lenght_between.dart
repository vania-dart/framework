import 'package:vaniaFramework/src/http/validation/validation_chain/validation_rule.dart';

class LengthBetween extends ValidationRule {
  final num lowerBoundary;
  final num higherBoundary;
  LengthBetween(
      {super.message,
      required this.lowerBoundary,
      required this.higherBoundary});

  @override
  bool validate(value, data) {
    value = value.toString().length;
    return value >= lowerBoundary && value <= higherBoundary;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field should between $lowerBoundary and $higherBoundary';
  }
}
