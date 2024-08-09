import 'package:vania/src/env_handler/parser/parser.dart';

class NumParser implements Parser<num> {
  @override
  num parse(String value) => num.parse(value);
}
