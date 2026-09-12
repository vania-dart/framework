import '../../../http/validation/custom_validation_rule.dart';

abstract class FormValidation {
  dynamic rules();
  List<CustomValidationRule> customRule() => [];
  Map<String, String> messages() => {};
  bool authorize() => true;
}
