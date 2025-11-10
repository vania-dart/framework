import 'abs_processor.dart';
import 'evaluate_expression.dart';
import '../template_engine.dart';

/// A processor that handles  `{@ if ... @}` if statements with
/// optional `{@ elseif ... @}` and `{@ else @}` sections.
///
/// Example:
/// ```html
///   {@ if is_admin @}
///     You are admin
///   {@ else @}
///     Not admin
///   {@ endif @}
/// ```
/// nested if statements
/// ```html
///   {@ if is_admin @}
///     {@ if name == 'Vania' @}Hello @{name}!{@ else @}Hello other admin{@ endif @}
///   {@ else @}
///     Not admin
///   {@ endif @}
/// ```
///
class IfStatementProcessor implements AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    context ??= {};
    return _parseIfBlocks(content, context);
  }

  /// Parse and replace `{@ if ... @}` blocks in [template] with values from [context].
  ///
  /// This implementation supports nested if statements.
  ///
  /// The replacement is done by expanding the block content if the condition is true.
  /// If the condition is false, the block content is not expanded.
  ///
  /// The following example:
  /// ```html
  ///   {@ if is_admin @}
  ///     You are admin
  ///   {@ else @}
  ///     Not admin
  ///   {@ endif @}
  /// ```
  /// Is replaced with "You are admin" if `is_admin` is true in the context,
  /// and "Not admin" if `is_admin` is false.
  ///
  String _parseIfBlocks(String template, Map<String, dynamic> context) {
    final buffer = StringBuffer();
    int index = 0;

    while (true) {
      final startPos = template.indexOf('{@ if', index);
      if (startPos == -1) {
        buffer.write(template.substring(index));
        break;
      }
      buffer.write(template.substring(index, startPos));
      final ifStartClose = template.indexOf('@}', startPos);
      if (ifStartClose == -1) {
        buffer.write(template.substring(startPos));
        break;
      }
      final ifConditionExpr = template
          .substring(startPos + 5, ifStartClose)
          .trim();
      int blockStart = ifStartClose + 2;
      int searchPos = blockStart;
      int nested = 0;
      int endifPos = -1;

      while (true) {
        final nextIf = template.indexOf('{@ if', searchPos);
        final nextEndif = template.indexOf('{@ endif @}', searchPos);
        if (nextEndif == -1) {
          break;
        }
        if (nextIf != -1 && nextIf < nextEndif) {
          nested++;
          searchPos = nextIf + 1;
        } else {
          if (nested > 0) {
            nested--;
            searchPos = nextEndif + 1;
          } else {
            endifPos = nextEndif;
            break;
          }
        }
      }

      if (endifPos == -1) {
        buffer.write(template.substring(blockStart));
        break;
      }

      final ifBlockContent = template.substring(blockStart, endifPos);

      final expanded = _expandIfBlock(ifConditionExpr, ifBlockContent, context);

      buffer.write(expanded);

      final endifClose = endifPos + '{@ endif @}'.length;
      index = endifClose;
    }

    return buffer.toString();
  }

  /// Expands an if-else block by evaluating conditions and returning the appropriate content.
  ///
  /// This function processes a block of content containing `if`, `elseif`, and `else` conditions,
  /// using the provided context to evaluate each condition. It returns the rendered string
  /// for the first true condition or the `else` block if no conditions are true.
  ///
  /// - Parameters:
  ///   - ifConditionExpr: The initial 'if' condition expression as a string.
  ///   - ifBlockContent: The content of the block to be evaluated.
  ///   - context: A map containing the context variables used for evaluating conditions.
  ///
  /// - Returns: A string with the expanded content for the first true condition or the `else` block.

  String _expandIfBlock(
    String ifConditionExpr,
    String ifBlockContent,
    Map<String, dynamic> context,
  ) {
    var cursor = 0;
    var currentCondition = ifConditionExpr;
    final segments = <_ConditionalSegment>[];

    final elseIfRegex = RegExp(r'\{@\s*elseif\s+(.*?)\s*@\}');
    final elseRegex = RegExp(r'\{@\s*else\s*@\}');

    while (true) {
      final matchElseIf = elseIfRegex.firstMatch(
        ifBlockContent.substring(cursor),
      );
      final matchElse = elseRegex.firstMatch(ifBlockContent.substring(cursor));

      final elseIfPos = (matchElseIf == null) ? -1 : cursor + matchElseIf.start;
      final elsePos = (matchElse == null) ? -1 : cursor + matchElse.start;

      int nextPos = -1;
      bool isElseIf = false;

      if (elseIfPos == -1 && elsePos == -1) {
      } else if (elseIfPos == -1) {
        nextPos = elsePos;
      } else if (elsePos == -1) {
        nextPos = elseIfPos;
        isElseIf = true;
      } else {
        if (elseIfPos < elsePos) {
          nextPos = elseIfPos;
          isElseIf = true;
        } else {
          nextPos = elsePos;
        }
      }

      if (nextPos == -1) {
        final block = ifBlockContent.substring(cursor);
        segments.add(
          _ConditionalSegment(
            condition: currentCondition,
            content: block,
            isConditionSegment: true,
          ),
        );
        break;
      } else {
        final block = ifBlockContent.substring(cursor, nextPos);
        segments.add(
          _ConditionalSegment(
            condition: currentCondition,
            content: block,
            isConditionSegment: true,
          ),
        );

        if (isElseIf) {
          final elseIfMatch = elseIfRegex.firstMatch(
            ifBlockContent.substring(nextPos),
          );
          if (elseIfMatch == null) break;
          currentCondition = elseIfMatch.group(1)!.trim();
          cursor = nextPos + elseIfMatch.end;
        } else {
          final elseMatch = elseRegex.firstMatch(
            ifBlockContent.substring(nextPos),
          );
          if (elseMatch == null) break;
          final elseStart = nextPos + elseMatch.end;
          final elseContent = ifBlockContent.substring(elseStart);

          segments.add(
            _ConditionalSegment(
              condition: '',
              content: elseContent,
              isConditionSegment: false,
            ),
          );
          break;
        }
      }
    }

    for (final seg in segments) {
      if (seg.isConditionSegment) {
        if (evaluateExpression(seg.condition, context)) {
          return TemplateEngine().renderString(seg.content, context);
        }
      } else {
        return TemplateEngine().renderString(seg.content, context);
      }
    }

    return '';
  }
}

class _ConditionalSegment {
  final String condition;
  final String content;
  final bool isConditionSegment;
  _ConditionalSegment({
    required this.condition,
    required this.content,
    required this.isConditionSegment,
  });
}
