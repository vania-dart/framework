import '_sql_identifier_escaper.dart';

abstract class IdentifierEscapingStrategy {
  String escape(String identifier);

  bool needsEscaping(String identifier);
}

class StandardEscapingStrategy implements IdentifierEscapingStrategy {
  final String quoteChar;

  final String? closingQuoteChar;

  const StandardEscapingStrategy(this.quoteChar, [this.closingQuoteChar]);

  @override
  String escape(String identifier) {
    if (!needsEscaping(identifier)) {
      return identifier;
    }

    String closing = closingQuoteChar ?? quoteChar;
    String escaped = identifier.replaceAll(quoteChar, '$quoteChar$quoteChar');

    if (quoteChar == '[') {
      escaped = identifier.replaceAll(']', ']]');
      return '[$escaped]';
    }

    return '$quoteChar$escaped$closing';
  }

  @override
  bool needsEscaping(String identifier) {
    return SqlIdentifierEscaper.needsEscaping(identifier);
  }
}
