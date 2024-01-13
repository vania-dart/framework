
import 'package:vania/src/extensions/map_extension.dart';

import 'validation_item.dart';

class NestedValidation {
  final String field;
  final Map<String, dynamic> data;
  final String rule;

  final List<ValidationItem> fieldsToValidate = <ValidationItem>[];

  NestedValidation({
    required this.data,
    required this.field,
    required this.rule,
  }) {
    _process();
  }

  void _process() {
    List<String> parts = field.split('.*.');

    /// eg. from products.*.{field} to products
    String mainField = parts[0];

    /// getting list of products from data.
    List<Map<String, dynamic>> list = data.getParam(mainField);

    /// remove main filed to loop and get final field to validate
    List<String> fieldsExceptMainField = parts.sublist(1);

    _processNestedField(mainField, fieldsExceptMainField, rule, list);
  }

  void _processNestedField(
    String mainField,
    List<String> fields,
    String rule,
    List<Map<String, dynamic>> items,
  ) {
    items.asMap().forEach((int index, Map<String, dynamic> item) {
      String field = fields.first;
      String fieldNameWithPositionIndex = '$mainField.$index.$field';

      /// this mean we already get field value to validate
      if (fields.length == 1) {
        dynamic value = item.getParam(field);

        fieldsToValidate.add(ValidationItem(
          field: fieldNameWithPositionIndex,
          name: field.split('.').last,
          value: value,
          rule: rule,
        ));
      }

      /// this mean we still need to get the actual field value
      else if (fields.length >= 2) {
        List<String> fieldsExceptMainField = fields.sublist(1);
        List<Map<String, dynamic>> newItems = item.getParam(field);

        _processNestedField(
          fieldNameWithPositionIndex,
          fieldsExceptMainField,
          rule,
          newItems,
        );
      }
    });
  }
}