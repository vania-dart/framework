import 'package:sprintf/sprintf.dart';
import 'package:vania/src/extensions/list_extension.dart';
import 'package:vania/src/extensions/map_extension.dart';

import 'nested_validation.dart';
import 'rules.dart';
import 'validation_item.dart';

class Validator {
  /// request data
  final Map<String, dynamic> data;

  Validator({required this.data});

  final Map<String, String> _errors = <String, String>{};
  List<String> get _methodNoNeedToSplitArguments => <String>['in'];

  /// check validation has errors
  bool get hasError => _errors.isNotEmpty;

  /// get list of error messages
  Map<String, String> get errors => _errors;

  /// add custom rule
  /// ```
  /// validator.customRule('unique', {
  ///   message: 'The {value} already exist',
  ///   fn: (Map<String, dynamic> data, dynamic value, String? arguments) {
  ///     /// add your logic here
  ///   }
  /// });
  /// ```
  void customRule({
    required String ruleName,
    required String message,
    required bool Function(Map<String, dynamic>, dynamic, String?) fn,
  }) {
    _matchingRules[ruleName] = <String, dynamic>{
      'message': message,
      'function': fn,
    };
  }

  /// set custom validator messages
  /// ```
  /// validator.setNewMessages({'required': 'The {field} is required});
  /// validator.setNewMessages({'name.required': 'The name is required});
  /// ```
  void setNewMessages(Map<String, String> messages) {
    messages.forEach((String key, String value) {
      List splitedKey = key.split('.');
      if (splitedKey.length > 1) {
        Function function = _matchingRules[splitedKey[1]]?['function'];
        _matchingRules[key] = <String, dynamic>{
          'message': value,
          'function': function,
        };
      } else if (_matchingRules[key] != null) {
        print(value);
        _matchingRules[key]?['message'] = value;
      }
    });
  }

  bool _isNestedValidation(String field) {
    return field.contains('.*.');
  }

  /// validate your data
  /// ```
  /// validator.validate({'field' : 'required|string'});
  /// ```
  void validate(Map<String, String> rules) {
    // print(_matchingRules);
    rules.forEach((String field, String rule) {
      if (_isNestedValidation(field)) {
        NestedValidation v =
            NestedValidation(data: data, field: field, rule: rule);
        for (ValidationItem item in v.fieldsToValidate) {
          _validateItem(item);
        }
      } else {
        _validateItem(ValidationItem(
          field: field,
          name: field.split('.').last,
          value: data.getParam(field),
          rule: rule,
        ));
      }
    });
  }

  void _validateItem(ValidationItem item) {
    List<String> rulesForEachName = item.rule.split('|');
    for (String rule in rulesForEachName) {
      String? error =
          _applyMatchingRule(item.field, item.name, item.value, rule);
      if (error != null) {
        _errors[item.field] = error;
        break;
      }
    }
  }

  String? _applyMatchingRule(
    String field,
    String name,
    dynamic value,
    String rule,
  ) {
    List<String> parts = rule.split(':');
    String ruleKey = parts.first.toString().toLowerCase();
    String args = parts.length >= 2 ? parts[1] : '';
    Map<String, dynamic>? match =
        _matchingRules["$name.$ruleKey"] ?? _matchingRules[ruleKey];
    if (match == null) {
      return null;
    }

    bool result =
        Function.apply(match['function'], <dynamic>[data, value, args]);
    if (result == true) {
      return null;
    }
    String error = match['message']
        .toString()
        .replaceAll('{field}', name)
        .replaceAll('{value}', value == null ? '' : value.toString());

    if (args.isNotEmpty) {
      List<String> arguments = _methodNoNeedToSplitArguments.contains(ruleKey)
          ? <String>[args.split(',').joinWithAnd()]
          : args.split(',');
      return sprintf(error, arguments);
    }

    return error;
  }

  final Map<String, Map<String, dynamic>> _matchingRules =
      <String, Map<String, dynamic>>{
    'required': <String, dynamic>{
      'message': 'The {field} is required',
      'function': Rules.isRequired,
    },
    'email': <String, dynamic>{
      'message': 'The {field} is not a valid email',
      'function': Rules.isEmail,
    },
    'string': <String, dynamic>{
      'message': 'The {field} must be a string',
      'function': Rules.isString,
    },
    'numeric': <String, dynamic>{
      'message': 'The {field} must be a number',
      'function': Rules.isNumeric,
    },
    'ip': <String, dynamic>{
      'message': 'The {field} must be an ip address',
      'function': Rules.isIp,
    },
    'boolean': <String, dynamic>{
      'message': 'The {field} must be a boolean',
      'function': Rules.isBoolean,
    },
    'integer': <String, dynamic>{
      'message': 'The {field} must be an integer',
      'function': Rules.isInteger,
    },
    'double': <String, dynamic>{
      'message': 'The {field} must be a double',
      'function': Rules.isDouble,
    },
    'array': <String, dynamic>{
      'message': 'The {field} must be an array',
      'function': Rules.isArray,
    },
    'json': <String, dynamic>{
      'message': 'The {field} is not a valid json',
      'function': Rules.isJson,
    },
    'alpha': <String, dynamic>{
      'message': 'The {field} must be an alphabetic',
      'function': Rules.isAlpha,
    },
    'alpha_dash': <String, dynamic>{
      'message': 'The {field} must be only alphabetic and dash',
      'function': Rules.isAlphaDash,
    },
    'alpha_numeric': <String, dynamic>{
      'message': 'The {field} must be only alphabetic and number',
      'function': Rules.isAlphaNumeric,
    },
    'date': <String, dynamic>{
      'message': 'The {field} must be a date',
      'function': Rules.isDate,
    },
    'url': <String, dynamic>{
      'message': 'The {field} must be a url',
      'function': Rules.isUrl,
    },
    'uuid': <String, dynamic>{
      'message': 'The {field} is invalid uuid',
      'function': Rules.isUUID,
    },
    'min_length': <String, dynamic>{
      'message': 'The {field} must be at least %s character',
      'function': Rules.minLength,
    },
    'max_length': <String, dynamic>{
      'message': 'The {field} may not be greater than %s character',
      'function': Rules.maxLength,
    },
    'length_between': <String, dynamic>{
      'message': 'The {field} must be between %s and %s character',
      'function': Rules.lengthBetween,
    },
    'between': <String, dynamic>{
      'message': 'The {field} must be between %s and %s',
      'function': Rules.between,
    },
    'in': <String, dynamic>{
      'message': 'The selected {field} is invalid. Valid options are %s',
      'function': Rules.inArray,
    },
    'not_in': <String, dynamic>{
      'message': 'The {field} field cannot be {value}',
      'function': Rules.notInArray,
    },
    'start_with': <String, dynamic>{
      'message': 'The {field} must start with %s',
      'function': Rules.startWith,
    },
    'end_with': <String, dynamic>{
      'message': 'The {field} must end with %s',
      'function': Rules.endWith,
    },
    'greater_than': <String, dynamic>{
      'message': 'The {field} must be greater than %s',
      'function': Rules.greaterThan,
    },
    'less_than': <String, dynamic>{
      'message': 'The {field} must be less than %s',
      'function': Rules.lessThan,
    },
    'min': <String, dynamic>{
      'message': 'The {field} must be greater than or equal %s',
      'function': Rules.min,
    },
    'max': <String, dynamic>{
      'message': 'The {field} must be less than or equal %s',
      'function': Rules.max,
    },
    'confirmed': <String, dynamic>{
      'message': 'The two password did not match',
      'function': Rules.confirmed,
    },
    'required_if': <String, dynamic>{
      'message': 'The {field} is required',
      'function': Rules.requiredIf,
    },
    'required_if_not': <String, dynamic>{
      'message': 'The {field} is required',
      'function': Rules.requiredIfNot,
    },
    'image': <String, dynamic>{
      'message': 'The {field} is either invalid or unsupported extension',
      'function': Rules.isImage,
    },
    'file': <String, dynamic>{
      'message': 'The {field} is either invalid or unsupported extension',
      'function': Rules.isFile,
    },
  };
}
