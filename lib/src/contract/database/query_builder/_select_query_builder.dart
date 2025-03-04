part of 'query_builder.dart';

abstract interface class SelectQueryBuilder {
  QueryBuilder addSelect(
    List<String> columns,
  );

  QueryBuilder select([
    List<String> columns,
  ]);

  QueryBuilder selectRaw(
    String expression, [
    List<dynamic> bindings = const [],
  ]);
  QueryBuilder selectSub(
    QueryBuilder subQuery,
    String as,
  );
}
