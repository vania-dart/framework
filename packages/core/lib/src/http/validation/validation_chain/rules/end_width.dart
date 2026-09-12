import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class EndWith extends ValidationRule {
  final String end;
  EndWith({required this.end, super.message});

  @override
  bool validate(value, data) {
    return value.toString().endsWith(end.toString());
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must end with $end';
  }
}
