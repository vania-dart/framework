import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsDouble extends ValidationRule {
  IsDouble({super.message});

  @override
  bool validate(value, data) {
    try {
      double.parse(value.toString());
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be a double';
  }
}
