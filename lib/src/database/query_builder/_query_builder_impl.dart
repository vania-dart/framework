import 'package:meta/meta.dart';
import '../../contract/database/query_builder/query_builder.dart';
import '../../exception/invalid_argument_exception.dart';
import '../_connection_manager.dart';
import '../monitoring/database_monitor.dart';
import '_bulk_operations_builder_impl.dart';
import '_cte_builder_impl.dart';
import '_delete_query_builder_impl.dart';
import '_insert_query_builder_impl.dart';
import '_join_clause_builder_impl.dart';
import '_where_clauses_builder_impl.dart';
import '_query_executor_builder_impl.dart';
import '_select_query_builder_impl.dart';
import '_union_clause_builder_impl.dart';
import '_update_query_builder_impl.dart';
import '_window_functions_builder_impl.dart';

class QueryBuilderImpl extends QueryBuilder
    with
        QueryExecutorBuilderImpl,
        InsertQueryBuilderImpl,
        UpdateQueryBuilderImpl,
        WhereClausesBuilderImpl,
        DeleteQueryBuilderImpl,
        SelectQueryBuilderImpl,
        JoinClauseBuilderImpl,
        UnionClauseBuilderImpl,
        WindowFunctionsBuilderImpl,
        BulkOperationsBuilderImpl,
        CteBuilderImpl {
  String _connectionName = 'mysql';
  final List<String> _orderBy = [];
  final List<String> _groupBy = [];
  final List<String> _having = [];

  String? _table;
  String? _tableAlias;
  int? _limit;
  int? _offset;
  int _paramCounter = 0;

  @override
  String get connectionName => _connectionName;
  set connectionName(String value) => _connectionName = value;

  @override
  String get getTable {
    String tableClause = (_table != null) ? "$_table" : "";
    if (_tableAlias != null && _tableAlias!.isNotEmpty) {
      tableClause += " AS $_tableAlias";
    }
    return tableClause;
  }

  @override
  RawExpression raw(value) => RawExpression(value);

  @override
  Future<bool> transaction(
    Future<dynamic> Function() queries, [
    String? conditionName,
  ]) =>
      ConnectionManager().transaction(queries, conditionName);

  @override
  Stream<DatabaseAlert> alerts() => ConnectionManager().alerts;

  @override
  Map<String, PerformanceStats> getPerformanceStats() =>
      ConnectionManager().getPerformanceStats();

  @protected
  @override
  String build({String? aggregateFunction, String? aggregateColumn}) {
    String sql = '';

    String withClause = buildWithClause();
    if (withClause.isNotEmpty) {
      sql = '$withClause ';
    }

    if (getTable.isNotEmpty) {
      if (aggregateFunction != null && aggregateColumn != null) {
        sql += "SELECT $aggregateFunction($aggregateColumn) FROM $getTable";
      } else {
        sql +=
            "SELECT ${selectColumns.isEmpty ? "*" : selectColumns.join(", ")} FROM $getTable";
      }

      if (joins.isNotEmpty) {
        sql += " ${joins.join(" ")}";
      }
      sql += conditions.isNotEmpty ? " WHERE ${conditions.join(" ")}" : "";

      if (unions.isNotEmpty) {
        sql += " ${unions.join(" ")}";
      }

      if (aggregateFunction == null && aggregateColumn == null) {
        if (_groupBy.isNotEmpty) {
          sql += " GROUP BY ${_groupBy.join(", ")}";
        }
        if (_having.isNotEmpty) {
          sql += " HAVING ${_having.join(" ")}";
        }
        if (_orderBy.isNotEmpty) {
          sql += " ORDER BY ${_orderBy.join(", ")}";
        }

        sql += (_limit != null) ? " LIMIT $_limit" : "";
        sql += (_offset != null) ? " OFFSET $_offset" : "";
      }
    } else if (conditions.isNotEmpty) {
      sql += conditions.join(" ");
    } else {
      sql += '';
    }

    return sql.trim();
  }

  @override
  QueryBuilder connection([String? connection]) {
    connectionName = connection ?? 'mysql';
    return this;
  }

  @override
  QueryBuilder groupBy(List<String> groups) {
    _groupBy.addAll(groups);
    return this;
  }

  @override
  QueryBuilder having(
    String column, [
    String? operator,
    dynamic value,
    String boolean = 'and',
  ]) {
    String clause;
    if (operator != null && value != null) {
      final paramName = _nextParamName();
      bindings[paramName] = value;
      clause = "$column $operator :$paramName";
    } else {
      clause = column;
    }
    if (_having.isEmpty) {
      _having.add(clause);
    } else {
      _having.add(" $boolean $clause");
    }
    return this;
  }

  @override
  QueryBuilder havingBetween(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
    bool not = false,
  }) {
    if (values.length < 2) {
      throw InvalidArgumentException(
        'The list of values must contain at least two items.',
      );
    }

    final paramName1 = _nextParamName();
    final paramName2 = _nextParamName();
    bindings[paramName1] = values[0];
    bindings[paramName2] = values[1];

    String clause =
        "$column ${not ? "NOT BETWEEN" : "BETWEEN"} :$paramName1 AND :$paramName2";
    if (_having.isEmpty) {
      _having.add(clause);
    } else {
      _having.add(" $boolean $clause");
    }
    return this;
  }

  @override
  QueryBuilder inRandomOrder([dynamic seed]) {
    if (seed != null) {
      _orderBy.add("RAND($seed)");
    } else {
      _orderBy.add("RAND()");
    }
    return this;
  }

  @override
  QueryBuilder latest([
    String column = 'created_at',
  ]) {
    return orderByDesc(column);
  }

  @override
  QueryBuilder limit(int value) {
    _limit = value;
    return this;
  }

  @override
  QueryBuilder offset(int value) {
    _offset = value;
    return this;
  }

  @override
  QueryBuilder orderBy(
    String column, [
    String direction = 'ASC',
  ]) {
    _orderBy.add("$column $direction");
    return this;
  }

  @override
  QueryBuilder orderByAsc(String column) {
    return orderBy(column, "ASC");
  }

  @override
  QueryBuilder orderByDesc(String column) {
    return orderBy(column, "DESC");
  }

  @override
  QueryBuilder reorder([
    String? column,
    String? direction,
  ]) {
    _orderBy.clear();
    if (column != null) {
      _orderBy.add("$column ${direction ?? 'asc'}");
    }
    return this;
  }

  @override
  QueryBuilder table(String table, [String? as]) {
    _table = table;
    _tableAlias = as;
    return this;
  }

  @override
  QueryBuilder skip(int value) => offset(value);

  @override
  QueryBuilder take(int value) => limit(value);

  @override
  String toSql() => build();

  @override
  String toRawSql() {
    String sql = build();
    final bindings = getBindings();

    bindings.forEach((key, value) {
      String placeholder = ':$key';
      String formattedValue = _formatValueForRawSql(value);
      sql = sql.replaceAll(placeholder, formattedValue);
    });

    return sql;
  }

  String _formatValueForRawSql(dynamic value) {
    if (value == null) {
      return 'NULL';
    } else if (value is RawExpression) {
      return value.toString();
    } else if (value is String) {
      return "'${value.replaceAll("'", "''")}'";
    } else if (value is num) {
      return value.toString();
    } else if (value is bool) {
      return value.toString();
    } else if (value is DateTime) {
      return "'${value.toIso8601String()}'";
    } else if (value is List) {
      return '(${value.map(_formatValueForRawSql).join(', ')})';
    } else {
      return "'${value.toString().replaceAll("'", "''")}'";
    }
  }

  @override
  Map<String, dynamic> getBindings() {
    Map<String, dynamic> allBindings = {};

    allBindings.addAll((this as WhereClausesBuilderImpl).bindings);

    allBindings.addAll(getCteBindings());
    (this as WhereClausesBuilderImpl).paramCounter = 0;
    return allBindings;
  }

  String _nextParamName() {
    _paramCounter++;
    return 'p$_paramCounter';
  }
}
