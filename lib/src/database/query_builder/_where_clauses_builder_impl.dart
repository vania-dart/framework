import '../../exception/invalid_argument_exception.dart';
import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder, QueryCallback;
import '../_database_utils/_singularize.dart';
import '_query_builder_impl.dart';

int _paramCounter = 0;

abstract mixin class WhereClausesBuilderImpl implements QueryBuilder {
  /// Valid SQL comparison operators to prevent SQL injection.
  /// Only these operators are allowed in where clauses.
  static const Set<String> _validOperators = {
    '=',
    '<>',
    '!=',
    '<',
    '>',
    '<=',
    '>=',
    'LIKE',
    'NOT LIKE',
    'ILIKE', // PostgreSQL case-insensitive LIKE
    'NOT ILIKE',
    'REGEXP',
    'NOT REGEXP',
    'RLIKE', // MySQL alias for REGEXP
    'SIMILAR TO', // PostgreSQL
  };

  set paramCounter(int paramN) {
    _paramCounter = paramN;
  }

  /// Returns the current parameter counter value.
  /// Useful for synchronizing nested queries.
  int get currentParamCounter => _paramCounter;

  String _nextParamName() {
    _paramCounter++;
    return 'p$_paramCounter';
  }

  /// Validates that the given operator is a valid SQL comparison operator.
  /// Throws [InvalidArgumentException] if the operator is not valid.
  /// This prevents SQL injection attacks through malicious operators.
  void _validateOperator(String operator) {
    if (!_validOperators.contains(operator.toUpperCase())) {
      throw InvalidArgumentException(
        'Invalid SQL operator: "$operator". '
        'Allowed operators: ${_validOperators.join(", ")}',
      );
    }
  }

  @override
  String buildWhereClause() {
    return conditions.isNotEmpty ? " WHERE ${conditions.join(" ")}" : "";
  }

  @override
  String build({String? aggregateFunction, String? aggregateColumn}) {
    throw UnimplementedError(
      'build() should be implemented by the concrete class',
    );
  }

  @override
  Map<String, dynamic> getBindings() {
    return bindings;
  }

  @override
  QueryBuilder orWhere(
    dynamic condition, [
    String operator = '=',
    dynamic value,
    String boolean = 'and',
  ]) {
    if (condition is String) {
      _validateOperator(operator);
      final paramName = _nextParamName();
      bindings[paramName] = value;
      _appendCondition("$condition $operator :$paramName", isOr: true);
    } else if (condition is QueryCallback) {
      QueryBuilderImpl nested = QueryBuilderImpl()
        ..paramCounter = _paramCounter;
      condition(nested);
      _appendCondition("(${nested.toSql()})", isOr: true);
      bindings.addAll(nested.getBindings());
    } else {
      throw InvalidArgumentException(
        'Invalid argument type for condition. Expected either a String or a QueryBuilder instance',
      );
    }
    return this;
  }

  @override
  QueryBuilder orWhereBetween(String column, List values, {bool not = false}) {
    _appendCondition(_createBetweenCondition(column, values, not), isOr: true);
    return this;
  }

  @override
  QueryBuilder orWhereColumn(
    String first,
    String operator,
    String secondColumn,
  ) {
    String condition = "$first $operator $secondColumn";
    _appendCondition(condition, isOr: true);
    return this;
  }

  @override
  QueryBuilder orWhereDate(String column, String operator, dynamic value) {
    _appendCondition(
      _createDateCondition(column, operator, value, "DATE"),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereDay(String column, String operator, dynamic value) {
    _appendCondition(
      _createDateCondition(column, operator, value, "DAY"),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereExists(QueryCallback callback, {bool not = false}) {
    QueryBuilder subQuery = QueryBuilderImpl();
    callback(subQuery);
    String condition = "${not ? 'NOT EXISTS' : 'EXISTS'} (${subQuery.toSql()})";
    _appendCondition(condition, isOr: true);
    bindings.addAll(subQuery.getBindings());
    return this;
  }

  @override
  QueryBuilder orWhereFullText(
    dynamic columns,
    dynamic query, [
    Map<String, dynamic> options = const {},
  ]) {
    _appendCondition(
      _createFullTextCondition(columns, query, options),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereHour(String column, String operator, dynamic value) {
    _appendCondition(_createHourCondition(column, operator, value), isOr: true);
    return this;
  }

  @override
  QueryBuilder orWhereIn(String column, List values, {bool not = false}) {
    _appendCondition(_createInCondition(column, values, not), isOr: true);
    return this;
  }

  @override
  QueryBuilder orWhereJsonContains(
    String column,
    dynamic value, {
    bool not = false,
  }) {
    _appendCondition(
      _createJsonContainsCondition(column, value, not),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereJsonDoesntContain(String column, dynamic value) {
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
      _createLikeCondition(
        column,
        value,
        not: false,
        caseSensitive: caseSensitive,
      ),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereMonth(String column, String operator, dynamic value) {
    _appendCondition(
      _createDateCondition(column, operator, value, "MONTH"),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereNotBetween(String column, List values) {
    _appendCondition(_createBetweenCondition(column, values, true), isOr: true);
    return this;
  }

  @override
  QueryBuilder orWhereNotExists(QueryCallback callback) {
    return orWhereExists(callback, not: true);
  }

  @override
  QueryBuilder orWhereNotIn(String column, dynamic values) {
    _appendCondition(_createInCondition(column, values, true), isOr: true);
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
      _createLikeCondition(
        column,
        value,
        not: true,
        caseSensitive: caseSensitive,
      ),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder orWhereNotNull(String column) {
    _appendCondition(_createNullCondition(column, true), isOr: true);
    return this;
  }

  @override
  QueryBuilder orWhereNull(String column) {
    _appendCondition(_createNullCondition(column, false), isOr: true);
    return this;
  }

  @override
  QueryBuilder orWhereRaw(String sql, [List<dynamic> rawBindings = const []]) {
    String processedSQL = _processRawSQL(sql, rawBindings);
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
  QueryBuilder orWhereTime(String column, String operator, dynamic value) {
    _appendCondition(
      _createDateCondition(column, operator, value, "TIME"),
      isOr: true,
    );
    return this;
  }

  @override
  QueryBuilder orWhereYear(String column, String operator, dynamic value) {
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
      _validateOperator(operator);
      final paramName = _nextParamName();
      bindings[paramName] = value;
      _appendCondition(
        "$condition $operator :$paramName",
        isOr: (boolean.toLowerCase() == 'or'),
      );
    } else if (condition is QueryCallback) {
      QueryBuilderImpl nested = QueryBuilderImpl()
        ..paramCounter = _paramCounter;
      condition(nested);
      _appendCondition(
        "(${nested.toSql()})",
        isOr: (boolean.toLowerCase() == 'or'),
      );
      bindings.addAll(nested.getBindings());
    } else {
      throw InvalidArgumentException(
        'Invalid argument type for condition. Expected either a String or a QueryBuilder instance',
      );
    }
    return this;
  }

  @override
  QueryBuilder whereAfterToday(String column, {String boolean = 'and'}) {
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
      throw InvalidArgumentException("The list of values must not be empty.");
    }

    List<String> conditions = [];
    for (var value in values) {
      final paramName = _nextParamName();
      bindings[paramName] = value;
      conditions.add("$column = :$paramName");
    }

    _appendCondition(
      conditions.join(" AND "),
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
      throw InvalidArgumentException("The list of values must not be empty.");
    }

    _appendCondition(
      _createInCondition(column, values, false),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereBeforeToday(String column, {String boolean = 'and'}) {
    _appendCondition(
      "DATE($column) < CURDATE()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereBetween(
    String column,
    List values, {
    String boolean = 'and',
    bool not = false,
  }) {
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
    String operator,
    String secondColumn, [
    String boolean = 'and',
  ]) {
    String condition = "$firstColumn $operator $secondColumn";
    _appendCondition(condition, isOr: (boolean.toLowerCase() == 'or'));
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
  QueryBuilder whereEqualTo(condition, [value, String boolean = 'and']) =>
      where(condition, '=', value, boolean);

  @override
  QueryBuilder whereExists(
    QueryCallback callback, {
    String boolean = 'and',
    bool not = false,
  }) {
    QueryBuilder subQuery = QueryBuilderImpl();
    callback(subQuery);
    String condition = "${not ? 'NOT EXISTS' : 'EXISTS'} (${subQuery.toSql()})";
    _appendCondition(condition, isOr: (boolean.toLowerCase() == 'or'));
    bindings.addAll(subQuery.getBindings());
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
  QueryBuilder whereFuture(String column, {String boolean = 'and'}) {
    _appendCondition("$column > NOW()", isOr: (boolean.toLowerCase() == 'or'));
    return this;
  }

  @override
  QueryBuilder whereGreaterThan(condition, [value, String boolean = 'and']) =>
      where(condition, '>', value, boolean);

  @override
  QueryBuilder whereGreaterThanOrEqualTo(
    condition, [
    value,
    String boolean = 'and',
  ]) => where(condition, '>=', value, boolean);

  @override
  QueryBuilder whereHour(
    String column,
    String operator,
    dynamic value, {
    String boolean = 'and',
  }) {
    _appendCondition(
      _createHourCondition(column, operator, value),
      isOr: (boolean.toLowerCase() == 'or'),
    );
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
  QueryBuilder whereLessThan(condition, [value, String boolean = 'and']) =>
      where(condition, '<', value, boolean);

  @override
  QueryBuilder whereLessThanOrEqualTo(
    condition, [
    value,
    String boolean = 'and',
  ]) => where(condition, '<=', value, boolean);

  @override
  QueryBuilder whereLike(
    String column,
    dynamic value, {
    bool caseSensitive = false,
    String boolean = 'and',
  }) {
    _appendCondition(
      _createLikeCondition(
        column,
        value,
        not: false,
        caseSensitive: caseSensitive,
      ),
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
      throw InvalidArgumentException("The list of values must not be empty.");
    }

    _appendCondition(
      _createInCondition(column, values, true),
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
  QueryBuilder whereNotEqualTo(condition, [value, String boolean = 'and']) =>
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
      _createLikeCondition(
        column,
        value,
        not: true,
        caseSensitive: caseSensitive,
      ),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereNotNull(String column, {String boolean = 'and'}) {
    _appendCondition(
      _createNullCondition(column, true),
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereNowOrFuture(String column, {String boolean = 'and'}) {
    _appendCondition("$column >= NOW()", isOr: (boolean.toLowerCase() == 'or'));
    return this;
  }

  @override
  QueryBuilder whereNowOrPast(String column, {String boolean = 'and'}) {
    _appendCondition("$column <= NOW()", isOr: (boolean.toLowerCase() == 'or'));
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
  QueryBuilder wherePast(String column, {String boolean = 'and'}) {
    _appendCondition("$column < NOW()", isOr: (boolean.toLowerCase() == 'or'));
    return this;
  }

  @override
  QueryBuilder whereRaw(
    String sql, [
    List<dynamic> rawBindings = const [],
    String boolean = 'and',
  ]) {
    String processedSQL = _processRawSQL(sql, rawBindings);
    _appendCondition(processedSQL, isOr: (boolean.toLowerCase() == 'or'));
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
  QueryBuilder whereToday(String column, {String boolean = 'and'}) {
    _appendCondition(
      "DATE($column) = CURDATE()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereTodayOrAfter(String column, {String boolean = 'and'}) {
    _appendCondition(
      "DATE($column) >= CURDATE()",
      isOr: (boolean.toLowerCase() == 'or'),
    );
    return this;
  }

  @override
  QueryBuilder whereTodayOrBefore(String column, {String boolean = 'and'}) {
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

  @override
  QueryBuilder whereHas(
    String relation,
    QueryCallback callback, {
    String boolean = 'and',
  }) {
    String condition = _createRelationshipCondition(relation, callback, false);
    _appendCondition(condition, isOr: (boolean.toLowerCase() == 'or'));
    return this;
  }

  @override
  QueryBuilder orWhereHas(String relation, QueryCallback callback) {
    String condition = _createRelationshipCondition(relation, callback, false);
    _appendCondition(condition, isOr: true);
    return this;
  }

  @override
  QueryBuilder whereDoesntHave(
    String relation,
    QueryCallback callback, {
    String boolean = 'and',
  }) {
    String condition = _createRelationshipCondition(relation, callback, true);
    _appendCondition(condition, isOr: (boolean.toLowerCase() == 'or'));
    return this;
  }

  @override
  QueryBuilder orWhereDoesntHave(String relation, QueryCallback callback) {
    String condition = _createRelationshipCondition(relation, callback, true);
    _appendCondition(condition, isOr: true);
    return this;
  }

  @override
  QueryBuilder withSoftDeletes([String column = 'deleted_at']) =>
      whereNull(column);

  String _createRelationshipCondition(
    String relation,
    QueryCallback callback,
    bool not,
  ) {
    if (relation.isEmpty) {
      throw InvalidArgumentException(
        'Relation name cannot be empty for relationship queries.',
      );
    }

    QueryBuilder subQuery = QueryBuilderImpl();

    subQuery.table(relation);

    callback(subQuery);

    String currentTable = getTable.split(' ').first;
    String foreignKey = '${Singularize.make(currentTable)}_id';

    subQuery.whereColumn('$relation.$foreignKey', '=', '$currentTable.id');

    String subQuerySQL = subQuery.toSql();
    bindings.addAll(subQuery.getBindings());

    String existsClause = not ? 'NOT EXISTS' : 'EXISTS';
    return "$existsClause (SELECT 1 FROM $relation WHERE $relation.$foreignKey = $currentTable.id AND (${_extractWhereFromSubQuery(subQuerySQL)}))";
  }

  String _extractWhereFromSubQuery(String sql) {
    int whereIndex = sql.indexOf('WHERE');
    if (whereIndex != -1) {
      return sql.substring(whereIndex + 5).trim();
    }
    return '1=1';
  }

  void _appendCondition(String condition, {bool isOr = false}) {
    if (conditions.isEmpty) {
      conditions.add(condition);
    } else {
      String joiner = isOr ? "OR" : "AND";
      conditions.add("$joiner $condition");
    }
  }

  String _createBetweenColumnsCondition(
    String column,
    List<String> columns, {
    bool not = false,
  }) {
    if (columns.length < 2) {
      throw InvalidArgumentException(
        'At least two columns must be provided for whereBetweenColumns.',
      );
    }
    String op = not ? "NOT BETWEEN" : "BETWEEN";
    return "$column $op ${columns[0]} AND ${columns[1]}";
  }

  String _createBetweenCondition(String column, List values, bool not) {
    if (values.length < 2) {
      throw InvalidArgumentException(
        'The list of values must contain at least two items.',
      );
    }

    final paramName1 = _nextParamName();
    final paramName2 = _nextParamName();
    bindings[paramName1] = values[0];
    bindings[paramName2] = values[1];

    return "$column ${not ? 'NOT BETWEEN' : 'BETWEEN'} :$paramName1 AND :$paramName2";
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

    final paramName = _nextParamName();
    bindings[paramName] = value;

    return "$function($column) $operator :$paramName";
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

    final paramName = _nextParamName();
    bindings[paramName] = query;

    String mode = "";
    if (options.containsKey('mode')) {
      mode = " IN ${options['mode']} MODE";
    }

    return "MATCH($colStr) AGAINST(:$paramName$mode)";
  }

  String _createHourCondition(String column, String operator, dynamic value) {
    if (value == null) {
      throw InvalidArgumentException(
        'The value for whereHour must not be null.',
      );
    }

    final paramName = _nextParamName();
    bindings[paramName] = value;

    return "HOUR($column) $operator :$paramName";
  }

  String _createInCondition(String column, dynamic values, bool not) {
    String clause = not ? "NOT IN" : "IN";

    if (values is List) {
      List<String> paramNames = [];
      for (var i = 0; i < values.length; i++) {
        final paramName = _nextParamName();
        bindings[paramName] = values[i];
        paramNames.add(":$paramName");
      }

      return "$column $clause (${paramNames.join(", ")})";
    } else if (values is QueryBuilder) {
      final subQuery = values.toSql();
      bindings.addAll((values as dynamic).getBindings());
      return "$column $clause ($subQuery)";
    } else {
      throw InvalidArgumentException(
        "The value for 'values' must be of type List or QueryBuilder.",
      );
    }
  }

  String _createJsonContainsCondition(String column, dynamic value, bool not) {
    final paramName = _nextParamName();
    bindings[paramName] = value;

    String condition = "JSON_CONTAINS($column, :$paramName)";
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
    final paramName = _nextParamName();
    bindings[paramName] = value;

    return "JSON_LENGTH($column) $operator :$paramName";
  }

  String _createLikeCondition(
    String column,
    dynamic value, {
    bool not = false,
    bool caseSensitive = false,
  }) {
    final paramName = _nextParamName();
    bindings[paramName] = value;

    String operator = not ? "NOT LIKE" : "LIKE";
    if (!caseSensitive) {
      return "LOWER($column) $operator LOWER(:$paramName)";
    }
    return "$column $operator :$paramName";
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

    List<String> paramNames = [];
    for (var i = 0; i < values.length; i++) {
      final paramName = _nextParamName();
      bindings[paramName] = values[i];
      paramNames.add(":$paramName");
    }

    String cols = "(${columns.join(", ")})";
    String vals = "(${paramNames.join(", ")})";

    return "$cols $operator $vals";
  }

  String _processRawSQL(String sql, List<dynamic> rawBindings) {
    String processed = sql;
    for (var binding in rawBindings) {
      final paramName = _nextParamName();
      bindings[paramName] = binding;
      processed = processed.replaceFirst('?', ':$paramName');
    }

    return processed;
  }
}
