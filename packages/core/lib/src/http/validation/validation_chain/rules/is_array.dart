import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsArray extends ValidationRule {
  IsArray({super.message});

  @override
  bool validate(value, data) {
    return value is List;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be an array';
  }
}
