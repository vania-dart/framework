import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class Confirmed extends ValidationRule {
  Confirmed({super.message});

  @override
  bool validate(value, data) {
    dynamic confirmValue = data['password_confirmation'];
    return confirmValue == value;
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'Both passwords should match';
  }
}
