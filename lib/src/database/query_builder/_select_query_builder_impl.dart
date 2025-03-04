import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder;

abstract mixin class SelectQueryBuilderImpl implements QueryBuilder {
  @override
  QueryBuilder addSelect(List<String> columns) {
    selectColumns.addAll(columns);
    return this;
  }

  @override
  QueryBuilder select([List<String> columns = const ['*']]) {
    selectColumns = List.from(columns);
    return this;
  }

  @override
  QueryBuilder selectRaw(String expression,
      [List<dynamic> bindings = const []]) {
    String processed = expression;
    for (var binding in bindings) {
      processed = processed.replaceFirst('?', formatValue(binding));
    }
    selectColumns.add(processed);
    return this;
  }

  @override
  QueryBuilder selectSub(QueryBuilder subQuery, String as) {
    String sub = "(${subQuery.toSql()}) AS $as";
    selectColumns.add(sub);
    return this;
  }
}
