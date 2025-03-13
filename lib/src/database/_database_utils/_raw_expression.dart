part of '../../contract/database/query_builder/query_builder.dart';

class RawExpression {
  final String expression;
  RawExpression(this.expression);

  @override
  String toString() => expression;
}
