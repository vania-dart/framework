import 'package:vania/src/view_engine/template_engine.dart';

import 'abs_processor.dart';

class OldProcessor extends AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    final oldPattern = RegExp(
      r"\{@\s*old\(\s*'([^']*)'\s*\)\s*@\}",
      dotAll: true,
    );

    content = content.replaceAllMapped(oldPattern, (oldMatch) {
      final oldKey = oldMatch.group(1);
      return TemplateEngine().formData[oldKey] ?? '';
    });

    return content;
  }
}
