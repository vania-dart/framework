import 'package:vania/src/config/defined_regexp.dart';
import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsAlphaDash extends ValidationRule {
  IsAlphaDash({super.message});

  @override
  bool validate(value, data) {
    return alphaDashRegExp.hasMatch(value.toString());
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field can just contains alphabet and also dash';
  }
}
