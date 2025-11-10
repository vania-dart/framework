import 'abs_processor.dart';
import 'dart:math';

class VariablesProcessor implements AbsProcessor {
  static final _variablePattern = RegExp(r'@\{(.*?)\}', dotAll: true);

  /// Replaces placeholders in the form of `@{expression}` with the evaluated value of [expression] in the context of [context].
  ///
  /// The following are valid expressions:
  ///
  /// - A variable name, e.g. `@{name}`
  ///
  /// If the expression evaluates to a non-string value, it is converted to a string.
  ///
  /// If the expression is invalid, or if the context does not contain a value for the specified variable,
  /// an empty string is returned.
  ///
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    context = context ?? {};

    return content.replaceAllMapped(_variablePattern, (match) {
      final rawExpression = match.group(1)?.trim() ?? '';
      if (rawExpression.isEmpty) return '';

      if (rawExpression.contains('|')) {
        return _handleVariableWithFilters(rawExpression, context ?? {});
      }

      if (_looksLikeVariablePath(rawExpression)) {
        final value = _fetchValueWithBracketNotation(
          rawExpression,
          context ?? {},
        );
        if (value != null) return value.toString();
      }

      final exprValue = _evaluateExpression(rawExpression, context ?? {});
      return exprValue?.toString() ?? '';
    });
  }

  /// Processes a variable expression with filters from the template content.
  ///
  /// This function splits the [rawExpression] into a variable name and filter
  /// operations. It fetches the variable value from the [context] using bracket
  /// notation, then sequentially applies each filter to the value.
  ///
  /// The filters are applied in the order they appear in the expression, and each
  /// filter transforms the value. If no filters are provided, the function returns
  /// the string representation of the variable's value. If the variable is not found
  /// in the context or an error occurs in fetching or filtering, an empty string is returned.
  ///
  /// - [rawExpression]: The raw expression containing the variable and optional filters.
  /// - [context]: The context map with variable values available for substitution.
  ///
  /// Returns the filtered variable value as a string.

  String _handleVariableWithFilters(
    String rawExpression,
    Map<String, dynamic> context,
  ) {
    final parts = rawExpression.split('|').map((e) => e.trim()).toList();
    final variableName = parts.first;
    final filters = parts.length > 1 ? parts.sublist(1) : <String>[];

    dynamic value = _fetchValueWithBracketNotation(variableName, context);

    for (final filter in filters) {
      value = _applyFilter(value, filter);
    }
    return value?.toString() ?? '';
  }

  bool _looksLikeVariablePath(String expr) {
    return expr.contains('.') || expr.contains('[');
  }

  /// Fetches a value from a [context] given a string expression.
  ///
  /// The [expression] can contain bracket notation, e.g. `user.name` or
  /// `users[0].name`. The value is fetched by splitting the expression into
  /// segments and resolving each segment on the current value.
  ///
  /// If the expression contains bracket index notation, e.g. `users[0]`, the
  /// bracket index is resolved to its value in the context by calling
  /// [_resolveBracketIndexVars].
  ///
  /// The function returns `null` if any segment in the expression is `null`.
  ///
  dynamic _fetchValueWithBracketNotation(
    String expression,
    Map<String, dynamic> context,
  ) {
    expression = _resolveBracketIndexVars(expression, context);

    final segments = expression.split('.');
    dynamic currentValue = context;

    for (final segment in segments) {
      currentValue = _resolveSegment(currentValue, segment);
      if (currentValue == null) return null;
    }
    return currentValue;
  }

  String _resolveBracketIndexVars(
    String expression,
    Map<String, dynamic> context,
  ) {
    final bracketVarRegex = RegExp(r'\[([^\[\]]+)\]');
    return expression.replaceAllMapped(bracketVarRegex, (m) {
      final inside = m.group(1)!;
      final asInt = int.tryParse(inside);
      if (asInt != null) {
        return '[$asInt]';
      }
      if (context.containsKey(inside) && context[inside] is int) {
        return '[${context[inside]}]';
      }
      return '[$inside]';
    });
  }

  /// Resolves a segment of a dot-separated expression on [currentValue].
  ///
  /// If [currentValue] is a map, the segment is resolved to a value in the map.
  /// If the segment is a bracket-index expression, e.g. `users[0]`, the
  /// expression is resolved to the value at the specified index in the list
  /// value associated with the key. If the key is not found, or the value is
  /// not a list, `null` is returned.
  ///
  /// If the segment is not a bracket-index expression, the segment is resolved
  /// to the value associated with the segment key. If the key is not found,
  /// `null` is returned.
  ///
  /// If [currentValue] is not a map, `null` is returned.
  dynamic _resolveSegment(dynamic currentValue, String segment) {
    if (currentValue == null) return null;

    if (currentValue is Map) {
      final bracketRegex = RegExp(r'^(\w+)\[(\d+)\]$');
      final match = bracketRegex.firstMatch(segment);
      if (match != null) {
        final mapKey = match.group(1)!;
        final indexStr = match.group(2)!;
        if (!currentValue.containsKey(mapKey)) return null;
        final listObj = currentValue[mapKey];
        if (listObj is List) {
          final idx = int.parse(indexStr);
          if (idx < 0 || idx >= listObj.length) return null;
          return listObj[idx];
        }
        return null;
      } else {
        if (!currentValue.containsKey(segment)) return null;
        return currentValue[segment];
      }
    }
    return null;
  }

  /// Applies a filter to a value, and returns the filtered value.
  ///
  /// The available filters are:
  ///
  /// - `default:<value>`: If the value is null, returns `<value>`.
  /// - `join:<delimiter>`: If the value is a list, joins the elements with `<delimiter>`.
  /// - `uppercase`: If the value is a string, returns its uppercase version.
  /// - `lowercase`: If the value is a string, returns its lowercase version.
  ///
  /// Otherwise, returns the original value.
  dynamic _applyFilter(dynamic value, String filter) {
    final defaultPattern = RegExp(r'^default:\s*(.*)$');
    if (defaultPattern.hasMatch(filter)) {
      if (value == null) {
        final match = defaultPattern.firstMatch(filter);
        var defaultVal = match?.group(1)?.trim() ?? '';
        defaultVal = defaultVal.replaceAll(RegExp(r'^"|"$'), '');
        defaultVal = defaultVal.replaceAll(RegExp(r"^'|'$"), '');
        return defaultVal;
      }
      return value;
    }

    final joinPattern = RegExp(r'^join:\s*(.*)$');
    if (joinPattern.hasMatch(filter)) {
      if (value is List) {
        final match = joinPattern.firstMatch(filter);
        var delimiter = match?.group(1)?.trim() ?? ',';
        delimiter = delimiter.replaceAll(RegExp(r'^"|"$'), '');
        delimiter = delimiter.replaceAll(RegExp(r"^'|'$"), '');
        return value.join(delimiter);
      }
      return value;
    }

    if (filter == 'uppercase') {
      if (value is String) return value.toUpperCase();
      return value;
    }

    if (filter == 'lowercase') {
      if (value is String) return value.toLowerCase();
      return value;
    }

    return value;
  }

  /// Evaluates an expression in the given context.
  ///
  /// The expression can contain:
  ///
  /// - ternary expressions: `cond ? trueVal : falseVal`
  /// - comparison operators: `==`, `!=`, `>=`, `<=`, `>`, `<`
  /// - arithmetic operators: `+`, `-`, `*`, `/`, `%`, `^`
  /// - any valid Dart expression
  ///
  /// The context is used to resolve any variables used in the expression.
  ///
  /// Returns the result of the expression, or `null` if the expression is invalid.
  dynamic _evaluateExpression(String expr, Map<String, dynamic> context) {
    expr = expr.trim();

    final ternaryPattern = RegExp(r'^(.+?)\?(.*?)\:(.*)$');
    final tMatch = ternaryPattern.firstMatch(expr);
    if (tMatch != null) {
      final condRaw = tMatch.group(1)!.trim();
      final trueRaw = tMatch.group(2)!.trim();
      final falseRaw = tMatch.group(3)!.trim();

      final condVal = _evaluateExpression(condRaw, context);
      final boolCond = (condVal is bool) ? condVal : _boolFromAnything(condVal);
      if (boolCond) {
        return _evaluateExpression(trueRaw, context);
      } else {
        return _evaluateExpression(falseRaw, context);
      }
    }

    final comparisonPattern = RegExp(r'(.+?)(==|!=|>=|<=|>|<)(.+)');
    final compMatch = comparisonPattern.firstMatch(expr);
    if (compMatch != null) {
      final leftRaw = compMatch.group(1)!.trim();
      final op = compMatch.group(2)!.trim();
      final rightRaw = compMatch.group(3)!.trim();

      final leftVal = _evalOperand(leftRaw, context);
      final rightVal = _evalOperand(rightRaw, context);
      return _compareValues(leftVal, rightVal, op);
    }

    final arithmeticPattern = RegExp(r'(.+?)(\+|\-|\*|\/|\%|\^)(.+)');
    final arithMatch = arithmeticPattern.firstMatch(expr);
    if (arithMatch != null) {
      final leftRaw = arithMatch.group(1)!.trim();
      final op = arithMatch.group(2)!.trim();
      final rightRaw = arithMatch.group(3)!.trim();

      final leftVal = _evalOperand(leftRaw, context);
      final rightVal = _evalOperand(rightRaw, context);
      return _arithValues(leftVal, rightVal, op);
    }

    return _evalOperand(expr, context);
  }

  dynamic _evalOperand(String raw, Map<String, dynamic> context) {
    final asInt = int.tryParse(raw);
    if (asInt != null) return asInt;

    final asDouble = double.tryParse(raw);
    if (asDouble != null) return asDouble;

    if (raw == 'true') return true;
    if (raw == 'false') return false;

    final val = _fetchValueWithBracketNotation(raw, context);
    if (val != null) return val;

    return raw;
  }

  bool _compareValues(dynamic left, dynamic right, String operator) {
    if (left is num && right is num) {
      switch (operator) {
        case '==':
          return left == right;
        case '!=':
          return left != right;
        case '>':
          return left > right;
        case '>=':
          return left >= right;
        case '<':
          return left < right;
        case '<=':
          return left <= right;
      }
    }

    final lstr = left?.toString() ?? '';
    final rstr = right?.toString() ?? '';
    switch (operator) {
      case '==':
        return lstr == rstr;
      case '!=':
        return lstr != rstr;
      case '>':
        return lstr.compareTo(rstr) > 0;
      case '>=':
        return lstr.compareTo(rstr) >= 0;
      case '<':
        return lstr.compareTo(rstr) < 0;
      case '<=':
        return lstr.compareTo(rstr) <= 0;
    }
    return false;
  }

  dynamic _arithValues(dynamic left, dynamic right, String operator) {
    if (left is num && right is num) {
      switch (operator) {
        case '+':
          return left + right;
        case '-':
          return left - right;
        case '*':
          return left * right;
        case '/':
          return right == 0 ? null : left / right;
        case '%':
          return right == 0 ? null : left % right;
        case '^':
          return pow(left, right);
      }
    }
    if (operator == '+') {
      return '${left?.toString() ?? ''}${right?.toString() ?? ''}';
    }
    return null;
  }

  /// Convert any value to a boolean.
  ///
  /// If the value is already a boolean, it is returned as is.
  ///
  /// If the value is a string, it is converted to lower case and compared to
  /// "true" and "false". If it matches one of those, the corresponding boolean
  /// is returned. Otherwise, `false` is returned.
  ///
  /// If the value is a number, it is converted to a boolean by checking if it
  /// is not equal to 0.
  ///
  /// For all other values, `null` is converted to `false`, and all other values
  /// are converted to `true`.
  bool _boolFromAnything(dynamic val) {
    if (val is bool) return val;
    if (val is String) {
      final lower = val.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }

    if (val is num) {
      return val != 0;
    }

    return val != null;
  }
}
