import '../impl/legacy_query_builder.dart' show QueryBuilder;
import '_sql_identifier_guard.dart';
import '_where_clauses_builder_impl.dart';

abstract mixin class SelectQueryBuilderImpl implements QueryBuilder {
  @override
  QueryBuilder addSelect(List<String> columns) {
    SqlIdentifierGuard.columns(columns, context: 'Select column');
    selectColumns.addAll(columns);
    return this;
  }

  @override
  QueryBuilder select([List<String> columns = const ['*']]) {
    SqlIdentifierGuard.columns(columns, context: 'Select column');
    selectColumns = List.from(columns);
    return this;
  }

  @override
  QueryBuilder selectRaw(String query, [List bindings = const []]) {
    // Placeholders are allocated from the builder's shared counter so
    // they cannot collide with names the where clauses have already
    // bound.
    final counter = this as WhereClausesBuilderImpl;
    var next = counter.currentParamCounter;

    for (var i = 0; i < bindings.length; i++) {
      next++;
      final paramName = 'p$next';
      this.bindings[paramName] = bindings[i];
      query = query.replaceFirst('?', ':$paramName');
    }

    counter.paramCounter = next;
    selectColumns.add(query);
    return this;
  }

  @override
  QueryBuilder selectSub(QueryBuilder subQuery, String as) {
    SqlIdentifierGuard.alias(as);
    String sub = "(${subQuery.toRawSql()}) AS $as";
    selectColumns.add(sub);
    return this;
  }
}
