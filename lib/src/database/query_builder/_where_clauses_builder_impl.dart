import '../../exception/invalid_argument_exception.dart';
import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder, QueryCallback;
import '_query_builder_impl.dart';

abstract mixin class WhereClausesBuilderImpl implements QueryBuilder {
  @override
  QueryBuilder orWhere(
    dynamic condition, [
    String operator = '=',
    dynamic value,
    String boolean = 'and',
  ]) {
    if (condition is String) {
      value = value is int ? value : "'$value'";
      _appendCondition("$condition $operator $value", isOr: true);
    } else if (condition is QueryCallback) {
      QueryBuilderImpl nested = QueryBuilderImpl();
      condition(nested);
      _appendCondition("(${nested.toSql()})", isOr: true);
    } else {
      throw InvalidArgumentException(
        'Invalid argument type for condition. Expected either a String or a QueryBuilder instance',
      );
    }
    return this;
  }

  @override
  QueryBuilder orWhereBetween(
    String column,
    List values, {
    bool not = false,
  }) {
    _appendCondition(
      _createBetweenCondition(column, values, not),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereColumn(
    String first,
    String? secondColumn, [
    String? operator,
  ]) {
    String op = operator ?? '=';
    String condition = "$first $op $secondColumn";
    _appendCondition(
      condition,
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereDate(
    String column,
    String operator,
    dynamic value,
  ) {
    _appendCondition(
      _createDateCondition(column, operator, value, "DATE"),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereDay(
    String column,
    String operator,
    dynamic value,
  ) {
    _appendCondition(
      _createDateCondition(column, operator, value, "DAY"),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereExists(
    QueryCallback callback, {
    bool not = false,
  }) {
    QueryBuilderImpl subQuery = QueryBuilderImpl();
    callback(subQuery);
    String condition = "${not ? 'NOT EXISTS' : 'EXISTS'} (${subQuery.toSql()})";
    _appendCondition(condition, isOr: true);
    return this;
  }

  @override
  QueryBuilder orWhereFullText(dynamic columns, dynamic query,
      [Map<String, dynamic> options = const {}]) {
    _appendCondition(
      _createFullTextCondition(columns, query, options),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereHour(
    String column,
    String operator,
    dynamic value,
  ) {
    _appendCondition(
      _createHourCondition(column, operator, value),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereIn(
    String column,
    List values, {
    bool not = false,
  }) {
    _appendCondition(
      _createInCondition(column, values, not),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereJsonContains(
    String column,
    dynamic value, {
    bool not = false,
  }) {
    _appendCondition(_createJsonContainsCondition(column, value, not),
        isOr: true);
    return this;
  }

  @override
  QueryBuilder orWhereJsonDoesntContain(
    String column,
    dynamic value,
  ) {
    _appendCondition(
      _createJsonContainsCondition(column, value, true),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereJsonLength(
    String column,
    String operator,
    dynamic value,
  ) {
    _appendCondition(
      _createJsonLengthCondition(column, operator, value),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
  }) {
    _appendCondition(
      _createLikeCondition(column, value,
          not: false, caseSensitive: caseSensitive),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereMonth(
    String column,
    String operator,
    dynamic value,
  ) {
    _appendCondition(
      _createDateCondition(column, operator, value, "MONTH"),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereNotBetween(String column, List values) {
    _appendCondition(
      _createBetweenCondition(column, values, true),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereNotExists(
    QueryCallback callback,
  ) {
    return orWhereExists(callback, not: true);
  }

  @override
  QueryBuilder orWhereNotIn(String column, dynamic values) {
    _appendCondition(
      _createInCondition(column, values, true),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereNotLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  }) {
    _appendCondition(
      _createLikeCondition(column, value,
          not: true, caseSensitive: caseSensitive),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder orWhereNotNull(String column) {
    _appendCondition(
      _createNullCondition(column, true),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereNull(String column) {
    _appendCondition(
      _createNullCondition(column, false),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereRaw(
    String sql, [
    List<dynamic> bindings = const [],
  ]) {
    String processedSQL = _processRawSQL(sql, bindings);
    _appendCondition(processedSQL, isOr: true);
    return this;
  }

  @override
  QueryBuilder orWhereRowValues(
    List<String> columns,
    String operator,
    List<dynamic> values,
  ) {
    _appendCondition(
      _createRowValuesCondition(columns, operator, values),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereTime(
    String column,
    String operator,
    dynamic value,
  ) {
    _appendCondition(
      _createDateCondition(column, operator, value, "TIME"),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereYear(
    String column,
    String operator,
    dynamic value,
  ) {
    _appendCondition(
      _createDateCondition(column, operator, value, "YEAR"),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder where(
    dynamic condition, [
    String operator = '=',
    dynamic value,
    String boolean = 'and',
  ]) {
    if (condition is String) {
      value = value is int ? value : "'$value'";
      _appendCondition("$condition $operator $value",
          isOr: (boolean.toLowerCase() == 'or'));
    } else if (condition is QueryCallback) {
      QueryBuilderImpl nested = QueryBuilderImpl();
      condition(nested);
      _appendCondition("(${nested.toSql()})",
          isOr: (boolean.toLowerCase() == 'or'));
    } else {
      throw InvalidArgumentException(
        'Invalid argument type for condition. Expected either a String or a QueryBuilder instance',
      );
    }
    return this;
  }

  @override
  QueryBuilder whereAfterToday(
    String column, {
    String boolean = 'and',
  }) {
    _appendCondition(
      "DATE($column) > CURDATE()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereAll(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  }) {
    if (values.isEmpty) {
      throw InvalidArgumentException(
        "The list of values must not be empty.",
      );
    }
    String condition;
    if (values.length == 1) {
      condition = "$column = ${formatValue(values.first)}";
    } else {
      condition =
          values.map((v) => "$column = ${formatValue(v)}").join(" AND ");
    }
    _appendCondition(
      condition,
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereAny(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  }) {
    if (values.isEmpty) {
      throw InvalidArgumentException(
        "The list of values must not be empty.",
      );
    }
    String formattedValues = values.map(formatValue).join(", ");
    String condition = "$column IN ($formattedValues)";
    _appendCondition(
      condition,
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereBeforeToday(
    String column, {
    String boolean = 'and',
  }) {
    _appendCondition(
      "DATE($column) < CURDATE()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereBetween(String column, List values,
      {String boolean = 'and', bool not = false}) {
    _appendCondition(
      _createBetweenCondition(column, values, not),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereBetweenColumns(
    String column,
    List<String> columns, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createBetweenColumnsCondition(column, columns),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereColumn(
    String firstColumn,
    String? secondColumn, [
    String? operator,
    String boolean = 'and',
  ]) {
    String op = operator ?? '=';
    if (secondColumn == null) {
      throw InvalidArgumentException(
        "The second column is required and cannot be empty.",
      );
    }
    String condition = "$firstColumn $op $secondColumn";
    _appendCondition(
      condition,
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereDate(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createDateCondition(column, operator, value, "DATE"),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereDay(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createDateCondition(column, operator, value, "DAY"),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereEqualTo(
    condition, [
    value,
    String boolean = 'and',
  ]) =>
      where(condition, '=', value, boolean);

  @override
  QueryBuilder whereExists(
    QueryCallback callback, {
    String boolean = 'and',
    bool not = false,
  }) {
    QueryBuilderImpl subQuery = QueryBuilderImpl();
    callback(subQuery);
    String condition = "${not ? 'NOT EXISTS' : 'EXISTS'} (${subQuery.toSql()})";
    _appendCondition(
      condition,
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereFullText(
    dynamic columns,
    dynamic query, [
    Map<String, dynamic> options = const {},
  ]) {
    _appendCondition(
      _createFullTextCondition(columns, query, options),
      isOr: false,
    );
    return this;
  }

  @override
  QueryBuilder whereFuture(
    String column, {
    String boolean = 'and',
  }) {
    _appendCondition(
      "$column > NOW()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereGreaterThan(
    condition, [
    value,
    String boolean = 'and',
  ]) =>
      where(condition, '>', value, boolean);

  @override
  QueryBuilder whereGreaterThanOrEqualTo(
    condition, [
    value,
    String boolean = 'and',
  ]) =>
      where(condition, '>=', value, boolean);

  @override
  QueryBuilder whereHour(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    _appendCondition(_createHourCondition(column, operator, value),
        isOr: (boolean.toLowerCase() == 'or'));
    return this;
  }

  @override
  QueryBuilder whereIn(
    String column,
    List values, {
    String boolean = 'and',
    bool not = false,
  }) {
    _appendCondition(
      _createInCondition(column, values, not),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereJsonContains(
    String column,
    dynamic value, {
    String boolean = 'and',
    bool not = false,
  }) {
    _appendCondition(
      _createJsonContainsCondition(column, value, not),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereJsonDoesntContain(
    String column,
    dynamic value, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createJsonContainsCondition(column, value, true),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereJsonLength(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createJsonLengthCondition(column, operator, value),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereLessThan(
    condition, [
    value,
    String boolean = 'and',
  ]) =>
      where(condition, '<', value, boolean);

  @override
  QueryBuilder whereLessThanOrEqualTo(
    condition, [
    value,
    String boolean = 'and',
  ]) =>
      where(condition, '<=', value, boolean);

  @override
  QueryBuilder whereLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  }) {
    _appendCondition(
      _createLikeCondition(column, value,
          not: false, caseSensitive: caseSensitive),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereMonth(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createDateCondition(column, operator, value, "MONTH"),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereNone(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
  }) {
    if (values.isEmpty) {
      throw InvalidArgumentException(
        "The list of values must not be empty.",
      );
    }
    String formattedValues = values.map(formatValue).join(", ");
    String condition = "$column NOT IN ($formattedValues)";
    _appendCondition(
      condition,
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereNotBetween(
    String column,
    List values, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createBetweenCondition(column, values, true),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereNotBetweenColumns(
    String column,
    List<String> columns, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createBetweenColumnsCondition(column, columns, not: true),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereNotEqualTo(
    condition, [
    value,
    String boolean = 'and',
  ]) =>
      where(condition, '<>', value, boolean);

  @override
  QueryBuilder whereNotExists(
    QueryCallback callback, {
    String boolean = 'and',
  }) {
    return whereExists(callback, boolean: boolean, not: true);
  }

  @override
  QueryBuilder whereNotIn(
    String column,
    dynamic values, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createInCondition(column, values, true),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereNotLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  }) {
    _appendCondition(
      _createLikeCondition(column, value,
          not: true, caseSensitive: caseSensitive),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereNotNull(
    String column, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createNullCondition(column, true),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereNowOrFuture(
    String column, {
    String boolean = 'and',
  }) {
    _appendCondition(
      "$column >= NOW()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereNowOrPast(
    String column, {
    String boolean = 'and',
  }) {
    _appendCondition(
      "$column <= NOW()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereNull(
    String column, {
    String boolean = 'and',
    bool not = false,
  }) {
    _appendCondition(
      _createNullCondition(column, not),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder wherePast(
    String column, {
    String boolean = 'and',
  }) {
    _appendCondition(
      "$column < NOW()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereRaw(
    String sql, [
    List<dynamic> bindings = const [],
    String boolean = 'and',
  ]) {
    String processedSQL = _processRawSQL(sql, bindings);
    _appendCondition(
      processedSQL,
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereRowValues(
    List<String> columns,
    String operator,
    List<dynamic> values, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createRowValuesCondition(columns, operator, values),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereTime(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createDateCondition(column, operator, value, "TIME"),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereToday(
    String column, {
    String boolean = 'and',
  }) {
    _appendCondition(
      "DATE($column) = CURDATE()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereTodayOrAfter(
    String column, {
    String boolean = 'and',
  }) {
    _appendCondition(
      "DATE($column) >= CURDATE()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereTodayOrBefore(
    String column, {
    String boolean = 'and',
  }) {
    _appendCondition(
      "DATE($column) <= CURDATE()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereYear(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createDateCondition(column, operator, value, "YEAR"),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  void _appendCondition(String condition, {bool isOr = false}) {
    if (conditions.isEmpty) {
      conditions.add(condition);
    } else {
      String joiner = isOr ? "OR" : "AND";
      conditions.add("$joiner $condition");
    }
  }

  String _createBetweenColumnsCondition(String column, List<String> columns,
      {bool not = false}) {
    if (columns.length < 2) {
      throw InvalidArgumentException(
        'At least two columns must be provided for whereBetweenColumns.',
      );
    }
    String op = not ? "NOT BETWEEN" : "BETWEEN";
    return "$column $op ${columns[0]} AND ${columns[1]}";
  }

  String _createBetweenCondition(
    String column,
    List values,
    bool not,
  ) {
    if (values.length < 2) {
      throw InvalidArgumentException(
        'The list of values must contain at least two items.',
      );
    }
    return "$column ${not ? 'NOT BETWEEN' : 'BETWEEN'} '${values[0]}' AND '${values[1]}'";
  }

  String _createDateCondition(
    String column,
    String operator,
    dynamic value,
    String function,
  ) {
    if (value == null) {
      throw InvalidArgumentException(
        'The value for the function $function must not be null.',
      );
    }
    return "$function($column) $operator ${formatValue(value)}";
  }

  String _createFullTextCondition(
    dynamic columns,
    dynamic query,
    Map<String, dynamic> options,
  ) {
    String colStr;
    if (columns is List) {
      colStr = columns.join(", ");
    } else {
      colStr = columns.toString();
    }
    String mode = "";
    if (options.containsKey('mode')) {
      mode = " ${options['mode']}";
    }
    return "MATCH($colStr) AGAINST(${formatValue(query)}$mode)";
  }

  String _createHourCondition(
    String column,
    String operator,
    dynamic value,
  ) {
    if (value == null) {
      throw InvalidArgumentException(
        'The value for whereHour must not be null.',
      );
    }
    return "HOUR($column) $operator ${formatValue(value)}";
  }

  String _createInCondition(
    String column,
    dynamic values,
    bool not,
  ) {
    String clause = not ? "NOT IN" : "IN";
    String inClause;
    if (values is List) {
      if (values.isEmpty) {
        throw InvalidArgumentException(
          "The list of values for IN must not be empty.",
        );
      }
      inClause = values.map((v) => formatValue(v)).join(", ");
    } else if (values is QueryBuilder) {
      inClause = values.toSql();
    } else {
      throw InvalidArgumentException(
        "The value for 'values' must be of type List or QueryBuilder.",
      );
    }
    return "$column $clause ($inClause)";
  }

  String _createJsonContainsCondition(
    String column,
    dynamic value,
    bool not,
  ) {
    String condition = "JSON_CONTAINS($column, ${formatValue(value)})";
    if (not) {
      condition = "NOT $condition";
    }
    return condition;
  }

  String _createJsonLengthCondition(
    String column,
    String operator,
    dynamic value,
  ) {
    return "JSON_LENGTH($column) $operator ${formatValue(value)}";
  }

  String _createLikeCondition(String column, dynamic value,
      {bool not = false, bool caseSensitive = false}) {
    String formattedValue = formatValue(value);
    String operator = not ? "NOT LIKE" : "LIKE";
    if (!caseSensitive) {
      return "LOWER($column) $operator LOWER($formattedValue)";
    }
    return "$column $operator $formattedValue";
  }

  String _createNullCondition(String column, bool not) {
    return "$column IS ${not ? 'NOT ' : ''}NULL";
  }

  String _createRowValuesCondition(
    List<String> columns,
    String operator,
    List<dynamic> values,
  ) {
    if (columns.length != values.length) {
      throw InvalidArgumentException(
        "The number of columns and values must be equal.",
      );
    }
    String cols = "(${columns.join(", ")})";
    String vals = "(${values.map((v) => formatValue(v)).join(", ")})";
    return "$cols $operator $vals";
  }

  String _processRawSQL(String sql, List<dynamic> bindings) {
    String processed = sql;
    for (var binding in bindings) {
      processed = processed.replaceFirst('?', formatValue(binding));
    }
    return processed;
  }
}
