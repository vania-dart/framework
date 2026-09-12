import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsInteger extends ValidationRule {
  IsInteger({super.message});

  @override
  bool validate(value, data) {
    try {
      int.parse(value.toString());
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be an integer';
  }
}
