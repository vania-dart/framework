import '../template_engine.dart';
import 'abs_processor.dart';

class ForLoopProcessor extends AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    context ??= {};

    return _parseForLoops(content, context);
  }

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
