import 'sql_grammar.dart';

class MySqlGrammar extends BaseGrammar {
  @override
  String get identifierQuote => '`';

  @override
  Map<String, String> get dataTypeMappings => {};

  @override
  Map<String, String> get keywordReplacements => {};

  @override
  Map<String, String Function(Match)> get regexTransformations => {};

  @override
  String convertQuery(String query) {
    return _cleanupQuery(query);
  }

  String _cleanupQuery(String query) {
    return query
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(',,', ',')
        .replaceAll(RegExp(r',\s?\)'), ')')
        .trim();
  }
}
