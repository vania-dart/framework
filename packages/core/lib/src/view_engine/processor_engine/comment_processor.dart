import 'abs_processor.dart';

class CommentProcessor implements AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    final commentPattern = RegExp(r"\{\@\#.*?\#\@\}", dotAll: true);
    return content.replaceAllMapped(commentPattern, (_) {
      return '';
    });
  }
}
