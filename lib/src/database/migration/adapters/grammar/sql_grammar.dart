abstract class SqlGrammar {
  String convertQuery(String query);

  String get identifierQuote;

  Map<String, String> get dataTypeMappings;

  Map<String, String> get keywordReplacements;

  Map<String, String Function(Match)> get regexTransformations;
}

abstract class BaseGrammar implements SqlGrammar {
  @override
  String convertQuery(String query) {
    String result = query;

    for (final entry in regexTransformations.entries) {
      result = result.replaceAllMapped(
        RegExp(entry.key, caseSensitive: false),
        entry.value,
      );
    }

    for (final entry in keywordReplacements.entries) {
      result = result.replaceAll(
        RegExp(entry.key, caseSensitive: false),
        entry.value,
      );
    }

    for (final entry in dataTypeMappings.entries) {
      result = result.replaceAll(
        RegExp(entry.key, caseSensitive: false),
        entry.value,
      );
    }

    result = result.replaceAll('`', identifierQuote);

    result = _cleanupQuery(result);

    return result;
  }

  String _cleanupQuery(String query) {
    return query
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(',,', ',')
        .replaceAll(RegExp(r',\s?\)'), ')')
        .trim();
  }
}
