import 'package:vania/src/view_engine/processor_engine/abs_processor.dart';
import 'package:vania/src/view_engine/template_engine.dart';

class SessionProcessor implements AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    final hasSessionPattern = RegExp(
      r"hasSession\(\s*'([^']*)'\s*\)",
      dotAll: true,
    );

    content = content.replaceAllMapped(hasSessionPattern, (match) {
      final sessionKey = match.group(1);
      return TemplateEngine().sessions.containsKey(sessionKey).toString();
    });

    final sessionPattern = RegExp(
      r"\{@\s*session\(\s*'([^']*)'\s*\)\s*@\}",
      dotAll: true,
    );

    content = content.replaceAllMapped(sessionPattern, (math) {
      final sessionKey = math.group(1);
      return TemplateEngine().sessions[sessionKey] ?? '';
    });

    return content;
  }
}
