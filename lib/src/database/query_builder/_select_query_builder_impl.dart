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
  QueryBuilder selectRaw(String query, [List bindings = const []]) {
    for (var i = 0; i < bindings.length; i++) {
      final paramName = 'raw_${i + 1}';
      this.bindings[paramName] = bindings[i];
      query = query.replaceFirst('?', ':$paramName');
    }

    selectColumns.add('($query)');
    return this;
  }

  @override
  QueryBuilder selectSub(QueryBuilder subQuery, String as) {
    String sub = "(${subQuery.toSql()}) AS $as";
    selectColumns.add(sub);
    return this;
  }
}
