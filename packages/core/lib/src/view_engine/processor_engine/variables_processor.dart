import 'abs_processor.dart';
import 'dart:convert' show htmlEscape;
import 'dart:math';

class VariablesProcessor implements AbsProcessor {
  /// Matches `@{expr}` and `@!{expr}`. Group 1 is `!` for the raw form,
  /// empty for the escaped form; group 2 is the expression.
  static final _variablePattern = RegExp(r'@(!?)\{(.*?)\}', dotAll: true);

  /// Replaces placeholders with the evaluated value of the expression in
  /// the context of [context].
  ///
  /// Two forms:
  ///
  /// - `@{expression}` — **HTML-escaped**. Use this everywhere.
  /// - `@!{expression}` — raw, inserted verbatim.
  ///
  /// Escaping is the default because template output is overwhelmingly
  /// user-controlled data.
  ///
  /// Only reach for `@!{…}` when the value is markup your own code
  /// produced. Anything derived from a request, a database column or a
  /// third-party API belongs in `@{…}`.
  ///
  /// If the expression is invalid, or the context has no value for it, the
  /// result is an empty string.
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    context = context ?? {};

    return content.replaceAllMapped(_variablePattern, (match) {
      final isRaw = match.group(1) == '!';
      final rawExpression = match.group(2)?.trim() ?? '';
      if (rawExpression.isEmpty) return '';

      final rendered = _render(rawExpression, context ?? {});
      if (isRaw || rendered is _RawHtml) return rendered.toString();
      return htmlEscape.convert(rendered.toString());
    });
  }

  /// Resolves an expression to its rendered form, before any escaping.
  /// Returns a [_RawHtml] when the chain ended in a `raw` filter.
  dynamic _render(String rawExpression, Map<String, dynamic> context) {
    if (rawExpression.contains('|')) {
      return _handleVariableWithFilters(rawExpression, context);
    }

    if (_looksLikeVariablePath(rawExpression)) {
      final value = _fetchValueWithBracketNotation(rawExpression, context);
      if (value != null) return value.toString();
    }

    final exprValue = _evaluateExpression(rawExpression, context);
    return exprValue?.toString() ?? '';
  }

  dynamic _handleVariableWithFilters(
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
    // Preserve a `raw` marker so the caller knows to skip escaping;
    // everything else collapses to a plain string.
    if (value is _RawHtml) return value;
    return value?.toString() ?? '';
  }

  bool _looksLikeVariablePath(String expr) {
    return expr.contains('.') || expr.contains('[');
  }

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

  dynamic _applyFilter(dynamic value, String filter) {
    if (filter == 'escape') {
      // Marked as raw so the default pass doesn't escape it a second time
      // and turn `&lt;` into `&amp;lt;`.
      return _RawHtml(htmlEscape.convert(value?.toString() ?? ''));
    }

    if (filter == 'raw') {
      return _RawHtml(value?.toString() ?? '');
    }

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

/// Marks a value produced by the `raw` filter so `@{…}` leaves it
/// unescaped. Deliberately private: templates can only obtain one through
/// an explicit `| raw`, so there is no way to smuggle unescaped output in
/// through the data map.
class _RawHtml {
  final String value;
  const _RawHtml(this.value);

  @override
  String toString() => value;
}
