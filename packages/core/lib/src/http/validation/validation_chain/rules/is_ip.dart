import 'package:vania/src/config/defined_regexp.dart';
import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsIp extends ValidationRule {
  IsIp({super.message});

  @override
  bool validate(value, data) {
    return ipRegExp.hasMatch(value.toString());
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field must be a valid IP address';
  }
}
