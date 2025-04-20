part of 'query_builder.dart';

abstract interface class UnionClauseBuilder {
  QueryBuilder union(QueryBuilder query);
  QueryBuilder unionAll(QueryBuilder query);
}
