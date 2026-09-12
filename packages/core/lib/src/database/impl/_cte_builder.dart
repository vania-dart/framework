part of 'legacy_query_builder.dart';

abstract class CteBuilder {
  QueryBuilder withCte(
    String name,
    QueryBuilder subQuery, {
    List<String>? columns,
  });

  QueryBuilder withMultiple(
    Map<String, QueryBuilder> ctes, {
    Map<String, List<String>>? columnsMap,
  });

  QueryBuilder withRecursive(
    String name,
    QueryBuilder baseCase,
    QueryBuilder recursiveCase, {
    List<String>? columns,
  });

  QueryBuilder withMaterialized(
    String name,
    QueryBuilder subQuery, {
    List<String>? columns,
  });

  QueryBuilder withNotMaterialized(
    String name,
    QueryBuilder subQuery, {
    List<String>? columns,
  });
}
