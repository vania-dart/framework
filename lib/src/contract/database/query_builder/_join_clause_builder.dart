part of 'query_builder.dart';

abstract interface class JoinClauseBuilder {
  QueryBuilder crossJoin(
    String table, [
    List<dynamic> bindings = const [],
  ]);

  QueryBuilder join(
    String table,
    String firstColumn, [
    String? operator,
    String? secondColumn,
    String type = 'inner',
    bool where = false,
  ]);

  QueryBuilder joinSub(
    QueryBuilder subQuery,
    String as,
    String firstColumn, [
    String? operator,
    String? secondColumn,
    String type = 'inner',
  ]);

  QueryBuilder leftJoin(
    String table,
    String firstColumn, [
    String? operator,
    String? secondColumn,
    bool where = false,
  ]);

  QueryBuilder leftJoinSub(
    QueryBuilder subQuery,
    String as,
    String firColumnst, [
    String? operator,
    String? secondColumn,
  ]);

  QueryBuilder rightJoin(
    String table,
    String firstColumn, [
    String? operator,
    String? secondColumn,
  ]);
}
