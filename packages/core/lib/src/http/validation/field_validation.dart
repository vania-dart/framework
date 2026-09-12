class FieldValidation {
  final String fieldName;
  final List<String> _rules = [];
  final Map<String, String> _messages = {};

  FieldValidation(this.fieldName);

  Map<String, String> get toMapMessages => _messages.map((key, message) {
    final parts = key.split('.*.');
    final ruleName = parts.isNotEmpty ? parts.last : key;
    return MapEntry(ruleName, message);
  });

  FieldValidation alpha({String? messages}) {
    _rules.add('alpha');
    if (messages != null) {
      _messages['$fieldName.alpha'] = messages;
    }
    return this;
  }

  FieldValidation alphaDash({String? messages}) {
    _rules.add('alpha_dash');
    if (messages != null) {
      _messages['$fieldName.alpha_dash'] = messages;
    }
    return this;
  }

  FieldValidation alphaNumeric({String? messages}) {
    _rules.add('alpha_numeric');
    if (messages != null) {
      _messages['$fieldName.alpha_numeric'] = messages;
    }
    return this;
  }

  FieldValidation between(int first, int second, {String? messages}) {
    _rules.add('between:$first,$second');
    if (messages != null) {
      _messages['$fieldName.between'] = messages;
    }
    return this;
  }

  FieldValidation boolean({String? messages}) {
    _rules.add('boolean');
    if (messages != null) {
      _messages['$fieldName.boolean'] = messages;
    }
    return this;
  }

  FieldValidation confirmed({String? messages}) {
    _rules.add('confirmed');
    if (messages != null) {
      _messages['$fieldName.confirmed'] = messages;
    }
    return this;
  }

  FieldValidation date({String? messages}) {
    _rules.add('date');
    if (messages != null) {
      _messages['$fieldName.date'] = messages;
    }
    return this;
  }

  FieldValidation dateTime({String? messages}) {
    _rules.add('date_time');
    if (messages != null) {
      _messages['$fieldName.date_time'] = messages;
    }
    return this;
  }

  FieldValidation email({String? messages}) {
    _rules.add('email');
    if (messages != null) {
      _messages['$fieldName.email'] = messages;
    }
    return this;
  }

  FieldValidation endWith(String value, {String? messages}) {
    _rules.add('end_with:$value');
    if (messages != null) {
      _messages['$fieldName.end_with'] = messages;
    }
    return this;
  }

  FieldValidation file(List<String> types, {String? messages}) {
    final formatted = 'file:${types.join(',')}';
    _rules.add(formatted);
    if (messages != null) {
      _messages['$fieldName.file'] = messages;
    }
    return this;
  }

  FieldValidation greaterThan(int value, {String? messages}) {
    _rules.add('greater_than:$value');
    if (messages != null) {
      _messages['$fieldName.greater_than'] = messages;
    }
    return this;
  }

  FieldValidation image({String? messages}) {
    _rules.add('image');
    if (messages != null) {
      _messages['$fieldName.image'] = messages;
    }
    return this;
  }

  FieldValidation integer({String? messages}) {
    _rules.add('integer');
    if (messages != null) {
      _messages['$fieldName.integer'] = messages;
    }
    return this;
  }

  FieldValidation ip({String? messages}) {
    _rules.add('ip');
    if (messages != null) {
      _messages['$fieldName.ip'] = messages;
    }
    return this;
  }

  FieldValidation isDouble({String? messages}) {
    _rules.add('double');
    if (messages != null) {
      _messages['$fieldName.double'] = messages;
    }
    return this;
  }

  FieldValidation isIn(List<String> value, {String? messages}) {
    _rules.add('in:${value.join(',')}');
    if (messages != null) {
      _messages['$fieldName.in'] = messages;
    }
    return this;
  }

  FieldValidation isList({String? messages}) {
    _rules.add('array');
    if (messages != null) {
      _messages['$fieldName.array'] = messages;
    }
    return this;
  }

  FieldValidation json({String? messages}) {
    _rules.add('json');
    if (messages != null) {
      _messages['$fieldName.json'] = messages;
    }
    return this;
  }

  FieldValidation lengthBetween(int first, int second, {String? messages}) {
    _rules.add('length_between:$first,$second');
    if (messages != null) {
      _messages['$fieldName.length_between'] = messages;
    }
    return this;
  }

  FieldValidation lessThan(int value, {String? messages}) {
    _rules.add('less_than:$value');
    if (messages != null) {
      _messages['$fieldName.less_than'] = messages;
    }
    return this;
  }

  FieldValidation max(int value, {String? messages}) {
    _rules.add('max:$value');
    if (messages != null) {
      _messages['$fieldName.max'] = messages;
    }
    return this;
  }

  FieldValidation maxLength(int value, {String? messages}) {
    _rules.add('max_length:$value');
    if (messages != null) {
      _messages['$fieldName.max_length'] = messages;
    }
    return this;
  }

  FieldValidation min(int value, {String? messages}) {
    _rules.add('min:$value');
    if (messages != null) {
      _messages['$fieldName.min'] = messages;
    }
    return this;
  }

  FieldValidation minLength(int value, {String? messages}) {
    _rules.add('min_length:$value');
    if (messages != null) {
      _messages['$fieldName.min_length'] = messages;
    }
    return this;
  }

  FieldValidation notIn(List<String> value, {String? messages}) {
    _rules.add('not_in:${value.join(',')}');
    if (messages != null) {
      _messages['$fieldName.not_in'] = messages;
    }
    return this;
  }

  FieldValidation numeric({String? messages}) {
    _rules.add('numeric');
    if (messages != null) {
      _messages['$fieldName.numeric'] = messages;
    }
    return this;
  }

  FieldValidation regExp(String rule, {String? messages}) {
    _rules.add('reg_exp:$rule');
    if (messages != null) {
      _messages['$fieldName.reg_exp'] = messages;
    }
    return this;
  }

  FieldValidation required({String? messages}) {
    _rules.add('required');
    if (messages != null) {
      _messages['$fieldName.required'] = messages;
    }
    return this;
  }

  FieldValidation requiredIf(List<String> value, {String? messages}) {
    _rules.add('required_if:${value.join(',')}');
    if (messages != null) {
      _messages['$fieldName.required_if'] = messages;
    }
    return this;
  }

  FieldValidation requiredIfNot(List<String> value, {String? messages}) {
    _rules.add('required_if_not:${value.join(',')}');
    if (messages != null) {
      _messages['$fieldName.required_if_not'] = messages;
    }
    return this;
  }

  FieldValidation startWith(String value, {String? messages}) {
    _rules.add('start_with:$value');
    if (messages != null) {
      _messages['$fieldName.start_with'] = messages;
    }
    return this;
  }

  FieldValidation string({String? messages}) {
    _rules.add('string');
    if (messages != null) {
      _messages['$fieldName.string'] = messages;
    }
    return this;
  }

  FieldValidation unique(String table, {String? messages}) {
    _rules.add('unique:$table,$fieldName');
    if (messages != null) {
      _messages['$fieldName.unique'] = messages;
    }
    return this;
  }

  FieldValidation url({String? messages}) {
    _rules.add('url');
    if (messages != null) {
      _messages['$fieldName.url'] = messages;
    }
    return this;
  }

  FieldValidation uuid({String? messages}) {
    _rules.add('uuid');
    if (messages != null) {
      _messages['$fieldName.uuid'] = messages;
    }
    return this;
  }

  @override
  String toString() {
    return _rules.join('|');
  }
}
