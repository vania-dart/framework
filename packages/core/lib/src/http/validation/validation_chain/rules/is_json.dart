import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsJson extends ValidationRule {
  IsJson({super.message});

  @override
  bool validate(value, data) {
    return value is Map;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be a Json';
  }
}
