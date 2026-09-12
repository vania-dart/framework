/// An interface (abstract class) for replacing placeholders in a template.
abstract class AbsProcessor {
  /// Replaces the placeholders in [content] with data from [context].
  String parse(String content, [Map<String, dynamic>? context]);
}
