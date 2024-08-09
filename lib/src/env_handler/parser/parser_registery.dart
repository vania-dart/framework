import 'package:vania/src/env_handler/parser/parser.dart';

class ParserRegistry {
  static final Map<Type, Parser> _parsers = {};

  static void registerParser<T>(Parser<T> parser) {
    _parsers[T] = parser;
  }

  static Parser<T>? getParser<T>() {
    return _parsers[T] as Parser<T>?;
  }
}
