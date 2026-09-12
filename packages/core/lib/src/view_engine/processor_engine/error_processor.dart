import 'package:vania/src/http/session/flash_messages.dart';

import 'abs_processor.dart';

class ErrorProcessor extends AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    final hasErrorPattern = RegExp(
      r"hasError\(\s*'([^']*)'\s*\)",
      dotAll: true,
    );
    content = content.replaceAllMapped(hasErrorPattern, (match) {
      final errorKey = match.group(1);
      return FlashMessages().errors.containsKey(errorKey).toString();
    });

    final errorPattern = RegExp(
      r"\{@\s*error\(\s*'([^']*)'\s*\)\s*@\}",
      dotAll: true,
    );

    content = content.replaceAllMapped(errorPattern, (error) {
      final errorKey = error.group(1);
      return FlashMessages().errors[errorKey] ?? '';
    });

    return content;
  }
}
