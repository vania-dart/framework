import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class IsRequired extends ValidationRule {
  IsRequired({super.message});

  @override
  bool validate(dynamic value, data) {
    return value != null && value.toString().isNotEmpty;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field is required';
  }
}
