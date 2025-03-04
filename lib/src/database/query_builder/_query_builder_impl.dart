import 'package:meta/meta.dart';

import '../../contract/database/query_builder/query_builder.dart';
import '../../exception/invalid_argument_exception.dart';
import '_delete_query_builder_impl.dart';
import '_insert_query_builder_impl.dart';
import '_join_clause_builder_impl.dart';
import '_where_clauses_builder_impl.dart';
import '_query_executor_builder_impl.dart';
import '_select_query_builder_impl.dart';
import '_union_clause_builder_impl.dart';
import '_update_query_builder_impl.dart';

class QueryBuilderImpl extends QueryBuilder
    with
        QueryExecutorBuilderImpl,
        InsertQueryBuilderImpl,
        UpdateQueryBuilderImpl,
        WhereClausesBuilderImpl,
        DeleteQueryBuilderImpl,
        SelectQueryBuilderImpl,
        JoinClauseBuilderImpl,
        UnionClauseBuilderImpl {
  final List<String> _orderBy = [];
  final List<String> _groupBy = [];
  final List<String> _having = [];

  String? _table;
  String? _tableAlias;
  int? _limit;
  int? _offset;

  @override
  String get table {
    String tableClause = (_table != null) ? "$_table" : "";
    if (_tableAlias != null && _tableAlias!.isNotEmpty) {
      tableClause += " AS $_tableAlias";
    }
    return tableClause;
  }

  @protected
  @override
  String build({String? aggregateFunction, String? aggregateColumn}) {
    String sql = '';

    if (table.isNotEmpty) {
      if (aggregateFunction != null && aggregateColumn != null) {
        sql = "SELECT $aggregateFunction($aggregateColumn) FROM $table";
      } else {
        sql =
            "SELECT ${selectColumns.isEmpty ? "*" : selectColumns.join(", ")} FROM $table";
      }

      if (joins.isNotEmpty) {
        sql += " ${joins.join(" ")}";
      }

      sql += conditions.isNotEmpty ? " WHERE ${conditions.join(" ")}" : "";

      if (unions.isNotEmpty) {
        sql += " ${unions.join(" ")}";
      }

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
    } else if (conditions.isNotEmpty) {
      sql = conditions.join(" ");
    } else {
      sql = '';
    }

    return sql;
  }

  QueryBuilderImpl connection([String? connection]) {
    connectionName = connection;
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
      clause = "$column $operator ${formatValue(value)}";
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
  QueryBuilder havingBetween(String column, List<dynamic> values,
      {String boolean = 'and', bool not = false}) {
    if (values.length < 2) {
      throw InvalidArgumentException(
        'The list of values must contain at least two items.',
      );
    }
    String clause =
        "$column ${not ? "NOT BETWEEN" : "BETWEEN"} ${formatValue(values[0])} AND ${formatValue(values[1])}";
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

  QueryBuilderImpl setTable(String table, [String? as]) {
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
}
