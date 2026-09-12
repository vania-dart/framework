import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class StartWith extends ValidationRule {
  final String start;
  StartWith({required this.start, super.message});

  @override
  bool validate(value, data) {
    return value.toString().startsWith(start.toString());
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must start with $start';
  }
}
