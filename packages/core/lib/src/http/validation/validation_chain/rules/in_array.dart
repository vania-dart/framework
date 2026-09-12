import 'package:vania/src/http/validation/validation_chain/validation_rule.dart';

class InArray<T> extends ValidationRule {
  final List<T> array;
  InArray({required this.array, super.message});

  @override
  bool validate(value, data) {
    return array.contains(value.toString());
  }

  @override
  String getDefaultErrorMessage(String field) {
    return 'The $field field have to a part of ${array.toString()}';
  }
}
