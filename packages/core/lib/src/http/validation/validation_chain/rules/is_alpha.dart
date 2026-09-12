import 'package:vania/src/config/defined_regexp.dart';
import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsAlpha extends ValidationRule {
  IsAlpha({super.message});

  @override
  bool validate(value, data) {
    return value is String && alphaRegExp.hasMatch(value);
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must contains just alphabet words';
  }
}
