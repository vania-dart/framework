bool evaluateExpression(String expression, Map<String, dynamic> context) {
  expression = _stripOuterParens(expression.trim());

  // Check for comparison: e.g. "leftSide == rightSide"
  // We separate the string into leftSide, operator, rightSide
  final comparisonPattern = RegExp(r'(.+?)\s*(==|!=|>=|<=|>|<)\s*(.+)');
  final compMatch = comparisonPattern.firstMatch(expression);
  if (compMatch != null) {
    final leftRaw = compMatch.group(1)!.trim();
    final op = compMatch.group(2)!.trim();
    final rightRaw = compMatch.group(3)!.trim();

    final leftVal = _evalArithmetic(leftRaw, context);
    final rightVal = _evalArithmetic(rightRaw, context);

    return _compare(leftVal, rightVal, op);
  }

  final singleVal = _evalArithmetic(expression, context);

  if (singleVal is bool) return singleVal;
  if (singleVal is num) return singleVal != 0;

  if (singleVal is String && singleVal.toLowerCase() == 'true') return true;

  final ctxVal = context[expression];

  if (ctxVal is bool) return ctxVal;

  return false;
}

/// Removes one set of outer parentheses if they exist, e.g. "(10 % 2)" => "10 % 2"
String _stripOuterParens(String expr) {
  final parenPattern = RegExp(r'^\((.*)\)$');
  final match = parenPattern.firstMatch(expr);
  if (match != null) {
    return match.group(1)!.trim();
  }
  return expr;
}

/// Evaluates a single arithmetic expression, e.g. "10 % 2", "i + 1", "5 * 3", or just "i".
/// Returns `num`, `bool`, or `String` depending on what we find.
dynamic _evalArithmetic(String expr, Map<String, dynamic> ctx) {
  expr = expr.trim();

  final asInt = int.tryParse(expr);
  if (asInt != null) return asInt;
  final asDouble = double.tryParse(expr);
  if (asDouble != null) return asDouble;

  final arithmeticPattern = RegExp(r'(.+?)\s*([\+\-\*\/%])\s*(.+)');
  final match = arithmeticPattern.firstMatch(expr);
  if (match != null) {
    final leftRaw = match.group(1)!.trim();
    final op = match.group(2)!.trim();
    final rightRaw = match.group(3)!.trim();

    final leftVal = _evalArithmetic(leftRaw, ctx);
    final rightVal = _evalArithmetic(rightRaw, ctx);

    return _doArithmetic(leftVal, rightVal, op);
  }

  final valFromContext = ctx[expr];
  if (valFromContext != null) return valFromContext;

  if (expr.toLowerCase() == 'true') return true;
  if (expr.toLowerCase() == 'false') return false;

  return expr;
}

/// Perform arithmetic on leftVal and rightVal with the single operator (+, -, *, /, %).
dynamic _doArithmetic(dynamic left, dynamic right, String op) {
  if (left is num && right is num) {
    switch (op) {
      case '+':
        return left + right;
      case '-':
        return left - right;
      case '*':
        return left * right;
      case '/':
        return (right == 0) ? null : left / right;
      case '%':
        return (right == 0) ? null : left % right;
    }
  }
  if (op == '+') {
    return '${left?.toString() ?? ''}${right?.toString() ?? ''}';
  }
  return null;
}

String removeOuterQuotes(String input) {
  if ((input.startsWith("'") && input.endsWith("'")) ||
      (input.startsWith('"') && input.endsWith('"'))) {
    return input.substring(1, input.length - 1);
  }
  return input;
}

/// Compare leftVal and rightVal with the given operator
bool _compare(dynamic leftVal, dynamic rightVal, String op) {
  if (leftVal is num && rightVal is num) {
    switch (op) {
      case '==':
        return leftVal == rightVal;
      case '!=':
        return leftVal != rightVal;
      case '>':
        return leftVal > rightVal;
      case '>=':
        return leftVal >= rightVal;
      case '<':
        return leftVal < rightVal;
      case '<=':
        return leftVal <= rightVal;
    }
  }
  if (op == '==') {
    return leftVal?.toString() == removeOuterQuotes(rightVal?.toString() ?? "");
  }
  if (op == '!=') {
    return leftVal?.toString() != removeOuterQuotes(rightVal?.toString() ?? "");
  }
  if (op == '>' || op == '>=' || op == '<' || op == '<=') {
    final lstr = leftVal?.toString() ?? '';
    final rstr = rightVal?.toString() ?? '';
    final cmp = lstr.compareTo(rstr);
    switch (op) {
      case '>':
        return cmp > 0;
      case '>=':
        return cmp >= 0;
      case '<':
        return cmp < 0;
      case '<=':
        return cmp <= 0;
    }
  }
  return false;
}
