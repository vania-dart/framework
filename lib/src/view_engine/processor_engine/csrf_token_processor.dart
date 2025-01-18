import 'package:vania/src/http/session/session_manager.dart';
import 'package:vania/src/view_engine/processor_engine/abs_processor.dart';

class CsrfTokenProcessor implements AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    final csrfMethodPattern = RegExp(
      r"\{@\s*csrf_token\(\)\s*@\}",
      dotAll: true,
    );

    return content.replaceAllMapped(csrfMethodPattern, (match) {
      return SessionManager().csrfToken;
    });
  }
}
