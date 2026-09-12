import 'dart:convert';

import 'package:vania/src/view_engine/processor_engine/abs_processor.dart';
import 'package:vania/src/view_engine/template_engine.dart';
import 'package:vania/src/view_engine/template_reader.dart';

class IncludeProcessor implements AbsProcessor {
  @override
  String parse(String content, [Map<String, dynamic>? context]) {
    final includePattern = RegExp(
      r"\{@\s*include\(\s*'([^']+)'\s*(,\s*(\{.*?\}))?\)\s*@\}",
      dotAll: true,
    );

    return content.replaceAllMapped(includePattern, (match) {
      final filePath = match.group(1) ?? '';

      final rawData = match.group(3) ?? '';

      final childContext = _parseIncludeData(rawData);
      final mergedContext = {...context ?? {}, ...childContext};

      final includedTemplate = FileTemplateReader().read(filePath);
      return TemplateEngine().renderString(includedTemplate, mergedContext);
    });
  }

  Map<String, dynamic> _parseIncludeData(String dataString) {
    dataString = dataString.trim();
    if (dataString.isEmpty) return {};

    try {
      final decoded = jsonDecode(dataString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return {};
  }
}
