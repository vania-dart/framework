import 'package:vania/src/http/validation/validation_chain/rules/is_required.dart';
import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class RequiredIfNot extends ValidationRule {
  final String payload;
  RequiredIfNot({required this.payload, super.message});

  @override
  bool validate(value, data) {
    List<String> parts = payload.toString().split(',');
    String secondField = parts[0];
    String secondFieldValueFromRule = parts[1].toString();
    String? secondFieldValueFromRequest = data[secondField].toString();

    /// check only when req value and rule value are same
    if (secondFieldValueFromRule != secondFieldValueFromRequest) {
      return IsRequired().validate(value, data);
    }
    return true;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field is Required';
  }
}
