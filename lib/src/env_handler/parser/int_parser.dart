import 'package:vania/src/env_handler/parser/parser.dart';

class IntParser implements Parser<int> {
  @override
  int parse(String value) => int.parse(value);
}
