import 'package:vania/src/view_engine/processor_engine/abs_processor.dart';

class SectionProcessor implements AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    final yieldPattern = RegExp(
      r"\{@\s*yield\(\s*'([^']+)'\s*\)\s*@\}",
      dotAll: true,
    );
    content = content.replaceAllMapped(yieldPattern, (match) {
      final sectionName = match.group(1) ?? '';
      return context?[sectionName] ?? '';
    });

    final parentSectionPattern = RegExp(
      r"\{@\s*section\(\s*'([^']+)'\s*\)\s*@\}(.*?)\{@\s*show\s*\}",
      dotAll: true,
    );

    content = content.replaceAllMapped(parentSectionPattern, (match) {
      final parentSectionName = match.group(1) ?? '';
      final parentContent = match.group(2) ?? '';
      final childContent = context?[parentSectionName];

      return childContent ?? parentContent;
    });
    return content;
  }

  Map<String, String> parseChildSections(String childTemplate) {
    final sections = <String, String>{};

    final blockSectionPattern = RegExp(
      r"\{@\s*section\(\s*'([^']+)'\s*\)\s*@\}(.*?)\{@\s*endsection\s*@\}",
      dotAll: true,
    );

    childTemplate = childTemplate.replaceAllMapped(blockSectionPattern, (
      match,
    ) {
      final sectionName = match.group(1) ?? '';
      final content = match.group(2) ?? '';
      sections[sectionName] = content;
      return '';
    });

    final inlineSectionPattern = RegExp(
      r"\{@\s*section\(\s*'([^']+)'\s*,\s*'(.*?)'\s*\)\s*@\}",
      dotAll: true,
    );

    childTemplate = childTemplate.replaceAllMapped(inlineSectionPattern, (
      match,
    ) {
      final sectionName = match.group(1) ?? '';
      final inlineContent = match.group(2) ?? '';
      sections[sectionName] = inlineContent;
      return '';
    });

    return sections;
  }
}
