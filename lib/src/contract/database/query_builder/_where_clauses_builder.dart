part of 'query_builder.dart';

abstract interface class WhereClausesBuilder {
  QueryBuilder orWhere(
    dynamic condition, [
    String operator = '=',
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder orWhereBetween(
    String column,
    List values, {
    bool not = false,
  });

  QueryBuilder orWhereColumn(
    String first,
    String? secondColumn, [
    String? operator,
  ]);

  QueryBuilder orWhereDate(
    String column,
    String operator,
    dynamic value,
  );

  QueryBuilder orWhereDay(
    String column,
    String operator,
    dynamic value,
  );

  QueryBuilder orWhereExists(
    QueryCallback callback, {
    bool not = false,
  });

  QueryBuilder orWhereFullText(
    dynamic columns,
    dynamic query, [
    Map<String, dynamic> options = const {},
  ]);

  QueryBuilder orWhereHour(
    String column,
    String operator,
    dynamic value,
  );

  QueryBuilder orWhereIn(
    String column,
    List values, {
    bool not = false,
  });
  QueryBuilder orWhereJsonContains(
    String column,
    dynamic value, {
    bool not = false,
  });
  QueryBuilder orWhereJsonDoesntContain(
    String column,
    dynamic value,
  );
  QueryBuilder orWhereJsonLength(
    String column,
    String operator,
    dynamic value,
  );

  QueryBuilder orWhereLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
  });
  QueryBuilder orWhereMonth(
    String column,
    String operator,
    dynamic value,
  );
  QueryBuilder orWhereNotBetween(
    String column,
    List values,
  );
  QueryBuilder orWhereNotExists(
    QueryCallback callback,
  );

  QueryBuilder orWhereNotIn(
    String column,
    List values,
  );
  QueryBuilder orWhereNotLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  });
  QueryBuilder orWhereNotNull(
    String column,
  );
  QueryBuilder orWhereNull(
    String column,
  );

  QueryBuilder orWhereRaw(
    String sql, [
    List<dynamic> bindings = const [],
  ]);
  QueryBuilder orWhereRowValues(
    List<String> columns,
    String operator,
    List<dynamic> values,
  );

  QueryBuilder orWhereTime(
    String column,
    String operator,
    dynamic value,
  );
  QueryBuilder orWhereYear(
    String column,
    String operator,
    dynamic value,
  );

  QueryBuilder where(
    dynamic condition, [
    String operator = '=',
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder whereAfterToday(
    String column, {
    String boolean = 'and',
  });

  QueryBuilder whereAll(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  });
  QueryBuilder whereAny(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  });

  QueryBuilder whereBeforeToday(
    String column, {
    String boolean = 'and',
  });
  QueryBuilder whereBetween(
    String column,
    List values, {
    String boolean = 'and',
    bool not = false,
  });

  QueryBuilder whereBetweenColumns(
    String column,
    List<String> columns, {
    String boolean = 'and',
  });
  QueryBuilder whereColumn(
    String firstColumn,
    String? secondColumn, [
    String? operator,
    String boolean = 'and',
  ]);

  QueryBuilder whereDate(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder whereDay(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });

  QueryBuilder whereEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder whereExists(
    QueryCallback callback, {
    String boolean = 'and',
    bool not = false,
  });

  QueryBuilder whereFullText(
    dynamic columns,
    dynamic query, [
    Map<String, dynamic> options = const {},
  ]);
  QueryBuilder whereFuture(
    String column, {
    String boolean = 'and',
  });

  QueryBuilder whereGreaterThan(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder whereGreaterThanOrEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);

  QueryBuilder whereHour(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder whereIn(
    String column,
    List values, {
    String boolean = 'and',
    bool not = false,
  });

  QueryBuilder whereJsonContains(
    String column,
    dynamic value, {
    String boolean = 'and',
    bool not = false,
  });
  QueryBuilder whereJsonDoesntContain(
    String column,
    dynamic value, {
    String boolean = 'and',
  });

  QueryBuilder whereJsonLength(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder whereLessThan(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);

  QueryBuilder whereLessThanOrEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder whereLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  });

  QueryBuilder whereMonth(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder whereNone(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  });

  QueryBuilder whereNotBetween(
    String column,
    List values, {
    String boolean = 'and',
  });
  QueryBuilder whereNotBetweenColumns(
    String column,
    List<String> columns, {
    String boolean = 'and',
  });
  QueryBuilder whereNotEqualTo(
    dynamic condition, [
    dynamic value,
    String boolean = 'and',
  ]);
  QueryBuilder whereNotExists(
    QueryCallback callback, {
    String boolean = 'and',
  });

  QueryBuilder whereNotIn(
    String column,
    List values, {
    String boolean = 'and',
  });

  QueryBuilder whereNotLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  });

  QueryBuilder whereNotNull(
    String column, {
    String boolean = 'and',
  });

  QueryBuilder whereNowOrFuture(
    String column, {
    String boolean = 'and',
  });
  QueryBuilder whereNowOrPast(
    String column, {
    String boolean = 'and',
  });
  QueryBuilder whereNull(
    String column, {
    String boolean = 'and',
    bool not = false,
  });
  QueryBuilder wherePast(
    String column, {
    String boolean = 'and',
  });
  QueryBuilder whereRaw(
    String sql, [
    List<dynamic> bindings = const [],
    String boolean = 'and',
  ]);
  QueryBuilder whereRowValues(
    List<String> columns,
    String operator,
    List<dynamic> values, {
    String boolean = 'and',
  });
  QueryBuilder whereTime(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });
  QueryBuilder whereToday(
    String column, {
    String boolean = 'and',
  });
  QueryBuilder whereTodayOrAfter(
    String column, {
    String boolean = 'and',
  });

  QueryBuilder whereTodayOrBefore(
    String column, {
    String boolean = 'and',
  });
  QueryBuilder whereYear(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  });

  QueryBuilder withSoftDeletes([String column = 'deleted_at']);
}
