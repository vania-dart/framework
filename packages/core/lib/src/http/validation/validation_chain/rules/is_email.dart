import 'package:vania/src/config/defined_regexp.dart';
import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsEmail extends ValidationRule {
  IsEmail({super.message});

  @override
  bool validate(dynamic value, data) {
    return value != null && emailRegExp.hasMatch(value.toString());
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be a valid email';
  }
}
