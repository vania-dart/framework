import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder;

abstract mixin class UnionClauseBuilderImpl implements QueryBuilder {
  @override
  QueryBuilder union(QueryBuilder query) {
    unions.add("UNION ${toSql()}");
    return this;
  }

  @override
  QueryBuilder unionAll(QueryBuilder query) {
    unions.add("UNION ALL ${toSql()}");
    return this;
  }
}
