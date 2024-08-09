import 'package:vania/src/env_handler/parser/parser.dart';

class BoolParser implements Parser<bool> {
  @override
  bool parse(String value) => bool.parse(value);
}
