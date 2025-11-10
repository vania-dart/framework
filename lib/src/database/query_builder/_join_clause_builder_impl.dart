import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder;

abstract mixin class JoinClauseBuilderImpl implements QueryBuilder {
  @override
  QueryBuilder crossJoin(String table, [List<dynamic> bindings = const []]) {
    String clause = "CROSS JOIN $table";
    joins.add(clause);
    return this;
  }

  @override
  QueryBuilder join(
    String table,
    String firstColumn, [
    String? operator,
    String? secondColumn,
    String type = 'INNER',
    bool where = false,
  ]) {
    String clause = "$type JOIN $table";
    if (operator != null && secondColumn != null) {
      clause += " ON $firstColumn $operator $secondColumn";
    }
    joins.add(clause);
    return this;
  }

  @override
  QueryBuilder joinSub(
    QueryBuilder subQuery,
    String as,
    String firstColumn, [
    String? operator,
    String? secondColumn,
    String type = 'inner',
  ]) {
    String subSql = "(${subQuery.toSql()}) AS $as";
    String clause = "$type JOIN $subSql";
    if (operator != null && secondColumn != null) {
      clause += " ON $firstColumn $operator $secondColumn";
    }
    joins.add(clause);
    return this;
  }

  @override
  QueryBuilder leftJoin(
    String table,
    String firstColumn, [
    String? operator,
    String? secondColumn,
    bool where = false,
  ]) {
    return join(table, firstColumn, operator, secondColumn, "LEFT", where);
  }

  @override
  QueryBuilder leftJoinSub(
    QueryBuilder subQuery,
    String as,
    String firstColumn, [
    String? operator,
    String? secondColumn,
  ]) {
    return joinSub(subQuery, as, firstColumn, operator, secondColumn, "LEFT");
  }

  @override
  QueryBuilder rightJoin(
    String table,
    String firstColumn, [
    String? operator,
    String? secondColumn,
  ]) {
    return join(table, firstColumn, operator, secondColumn, "RIGHT");
  }
}
