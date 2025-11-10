import '../template_engine.dart';
import 'abs_processor.dart';

/// processor to handles "for" loops, including **nested** loops.
class ForLoopProcessor extends AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    context ??= {};

    return _parseForLoops(content, context);
  }

  /// Parse and replace `{@ for ... @}` blocks in [template] with values from [context].
  ///
  /// This implementation supports nested loops.
  ///
  /// The replacement is done by expanding the loop content for each iteration of the loop.
  /// The loop variable is iterated over the iterable returned by the expression.
  /// Each iteration is replaced with the value of the loop variable.
  ///
  /// The following example:
  ///```html
  ///   {@ for user in users @}
  ///     {@ user.name @}
  ///   {@ endfor @}
  ///
  ///  {@ for i=0; i<3; i++ @}
  ///    Index ->: @{i} - Name: @{users[i].name}
  ///  {@ endfor @}
  ///```
  /// Is replaced with the contents of the loop block, with `user` replaced with each value of the iterable returned by the expression.
  ///
  String _parseForLoops(String template, Map<String, dynamic> context) {
    final buffer = StringBuffer();
    int index = 0;

    while (true) {
      final startPos = template.indexOf('{@ for', index);
      if (startPos == -1) {
        buffer.write(template.substring(index));
        break;
      }

      buffer.write(template.substring(index, startPos));

      final forStartClose = template.indexOf('@}', startPos);
      if (forStartClose == -1) {
        buffer.write(template.substring(startPos));
        break;
      }

      final forExpression = template
          .substring(startPos + 6, forStartClose)
          .trim();

      int loopContentStart = forStartClose + 2;
      int searchPos = loopContentStart;
      int nested = 0;
      int endforPos = -1;

      while (true) {
        final nextFor = template.indexOf('{@ for', searchPos);
        final nextEndfor = template.indexOf('{@ endfor @}', searchPos);

        if (nextEndfor == -1) {
          break;
        }

        if (nextFor != -1 && nextFor < nextEndfor) {
          nested++;
          searchPos = nextFor + 1;
        } else {
          if (nested > 0) {
            nested--;
            searchPos = nextEndfor + 1;
          } else {
            endforPos = nextEndfor;
            break;
          }
        }
      }

      if (endforPos == -1) {
        buffer.write(template.substring(loopContentStart));
        break;
      }
      final loopBlock = template.substring(loopContentStart, endforPos);

      final expanded = _expandLoop(forExpression, loopBlock, context);

      buffer.write(expanded);

      final endforClose = endforPos + '{@ endfor @}'.length;
      index = endforClose;
    }

    return buffer.toString();
  }

  /// Expands a loop expression into the rendered output based on the specified loop style.
  ///
  /// Handles two types of loop expressions:
  /// 1. C-style loops (e.g., `i=0; i<10; i++`), where it extracts the loop
  ///    control variables, start condition, end condition, and increment expression.
  /// 2. "Item in list" style loops (e.g., `item in items`), where it iterates
  ///    over each element in the list and processes the loop block.
  ///
  /// If the expression matches a C-style loop, it delegates execution to
  /// `_runCStyleLoop`. If it matches an "item in list" loop, it delegates to
  /// `_runItemInListLoop`. Returns the expanded loop content as a string.

  String _expandLoop(
    String forExpression,
    String loopBlock,
    Map<String, dynamic> context,
  ) {
    final cStylePattern = RegExp(
      r'^(\w+)\s*=\s*(.+?);\s*\1\s*([<>]=?|[<>])\s*(.+?);\s*(.+)$',
    );
    final cMatch = cStylePattern.firstMatch(forExpression);
    if (cMatch != null) {
      final varName = cMatch.group(1)!;
      final startExpr = cMatch.group(2)!;
      final operator = cMatch.group(3)!;
      final endExpr = cMatch.group(4)!;
      final incExpr = cMatch.group(5)!;

      return _runCStyleLoop(
        loopBlock: loopBlock,
        varName: varName,
        startExpr: startExpr,
        operator: operator,
        endExpr: endExpr,
        incExpr: incExpr,
        context: context,
      );
    }

    final itemInListPattern = RegExp(r'^(\w+)\s+in\s+(\w+)$');
    final inMatch = itemInListPattern.firstMatch(forExpression);
    if (inMatch != null) {
      final itemName = inMatch.group(1)!;
      final listName = inMatch.group(2)!;
      return _runItemInListLoop(loopBlock, itemName, listName, context);
    }

    return '';
  }

  /// Runs a loop block for each item in a list.
  ///
  /// The loop block is rendered for each item in the list, with the item
  /// assigned to a variable with the name given by [itemName]. The item's
  /// index in the list is also available as a variable named `'index'`.
  ///
  /// The loop block is rendered by calling [TemplateEngine().renderString] with
  /// the loop block as the template and a new context that includes the current
  /// item and index, as well as all of the variables from the original context.
  ///
  /// The output of the loop block is concatenated together and returned as a
  /// single string. If the specified list is not a list, an empty string is
  /// returned.
  String _runItemInListLoop(
    String loopBlock,
    String itemName,
    String listName,
    Map<String, dynamic> context,
  ) {
    final listObj = context[listName];
    if (listObj is! List) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < listObj.length; i++) {
      final item = listObj[i];
      final subCtx = {...context, itemName: item, 'index': i};

      buffer.write(TemplateEngine().renderString(loopBlock, subCtx));
    }
    return buffer.toString();
  }

  /// Runs a C-style for loop block for each iteration of the loop.
  ///
  /// The loop block is rendered for each iteration of the loop, with the current
  /// value of the loop variable assigned to a variable with the name given by
  /// [varName]. The loop block is rendered by calling
  /// [TemplateEngine().renderString] with the loop block as the template and a
  /// new context that includes the current value of the loop variable, as well
  /// as all of the variables from the original context.
  ///
  /// The output of the loop block is concatenated together and returned as a
  /// single string. If the specified loop variables are not valid, an empty
  /// string is returned.
  ///
  /// The loop iterates until the condition specified by [operator] is false.
  /// The condition is evaluated by calling [TemplateEngine().renderString] with
  /// the condition expression as the template and the current context.
  ///
  String _runCStyleLoop({
    required String loopBlock,
    required String varName,
    required String startExpr,
    required String operator,
    required String endExpr,
    required String incExpr,
    required Map<String, dynamic> context,
  }) {
    int current = _evalToInt(startExpr, context) ?? 0;

    bool checkCondition(int curVal) {
      final endVal = _evalToInt(endExpr, context) ?? 0;
      switch (operator) {
        case '<':
          return curVal < endVal;
        case '<=':
          return curVal <= endVal;
        case '>':
          return curVal > endVal;
        case '>=':
          return curVal >= endVal;
      }
      return false;
    }

    /// Increments the current value based on the increment expression.
    ///
    /// This function processes the increment expression [incExpr] to determine
    /// how to modify the [curVal]. It supports the following increment patterns:
    /// - `varName++` or `varName--`: increments or decrements the value by 1.
    /// - `varName += n` or `varName -= n`: adds or subtracts the specified amount.
    /// - `varName = varName + n` or `varName = varName - n`: adds or subtracts the specified amount.
    ///
    /// If no pattern is matched, the function defaults to incrementing the value by 1.
    ///
    /// Returns the new value after applying the increment.

    int increment(int curVal) {
      final trimmed = incExpr.trim();

      if (trimmed == '$varName++') {
        return curVal + 1;
      } else if (trimmed == '$varName--') {
        return curVal - 1;
      }

      final addSubPattern = RegExp(r'^' + varName + r'\s*([\+\-]=)\s*(\d+)$');
      final addSubMatch = addSubPattern.firstMatch(trimmed);
      if (addSubMatch != null) {
        final op = addSubMatch.group(1)!;
        final amt = int.parse(addSubMatch.group(2)!);
        return (op == '+=') ? curVal + amt : curVal - amt;
      }

      final assignPattern = RegExp(
        r'^' + varName + r'\s*=\s*' + varName + r'\s*([\+\-])\s*(\d+)$',
      );
      final assignMatch = assignPattern.firstMatch(trimmed);
      if (assignMatch != null) {
        final sign = assignMatch.group(1)!;
        final amt = int.parse(assignMatch.group(2)!);
        return (sign == '+') ? curVal + amt : curVal - amt;
      }

      return curVal + 1;
    }

    final buffer = StringBuffer();
    while (checkCondition(current)) {
      final subCtx = {...context, varName: current};

      buffer.write(TemplateEngine().renderString(loopBlock, subCtx));
      current = increment(current);
    }
    return buffer.toString();
  }

  /// Evaluates a string expression and attempts to convert it to an integer.
  ///
  /// This function processes the provided [expr] in the following ways:
  /// - Tries to parse [expr] directly as an integer.
  /// - Checks if the expression matches the pattern `<variable>.length`, and if
  ///   the variable in the [context] is a list, returns its length.
  /// - If [expr] is a key in the [context] and its value is an integer, returns
  ///   that integer.
  ///
  /// If none of the above conditions are met, the function returns `null`.
  ///
  /// **Parameters:**
  /// - [expr]: A string representing the expression to evaluate.
  /// - [context]: A map containing variable names and their corresponding values.
  ///
  /// **Returns:**
  /// An integer if the expression can be evaluated to an integer; otherwise, `null`.

  int? _evalToInt(String expr, Map<String, dynamic> context) {
    expr = expr.trim();

    final maybeInt = int.tryParse(expr);
    if (maybeInt != null) return maybeInt;

    final dotPattern = RegExp(r'^(\w+)\.length$');
    final dotMatch = dotPattern.firstMatch(expr);
    if (dotMatch != null) {
      final varName = dotMatch.group(1)!;
      final obj = context[varName];
      if (obj is List) return obj.length;
      return null;
    }

    if (context.containsKey(expr) && context[expr] is int) {
      return context[expr] as int;
    }
    return null;
  }
}
