import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsString extends ValidationRule {
  IsString({super.message});

  @override
  bool validate(value, data) {
    return value != null && value is String;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be a string';
  }
}
