import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class Validation {
  final String field;
  final List<ValidationRule> rules;
  const Validation({required this.field, required this.rules});
}
