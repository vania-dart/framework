import 'package:vania/src/env_handler/parser/parser.dart';

class DoubleParser implements Parser<double> {
  @override
  double parse(String value) => double.parse(value);
}
