import 'package:meta/meta.dart';
import '_sql_identifier_guard.dart';
import '../impl/legacy_query_builder.dart';
import 'package:vania/foundation.dart' show InvalidArgumentException, env;
import '../connection/connection_manager.dart';
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

final String _defaultConnectionName = env<String>('DB_CONNECTION', '');

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
  String _connectionName = _defaultConnectionName;
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
    final t = _table;
    if (t == null) return '';
    final a = _tableAlias;
    if (a == null || a.isEmpty) return t;
    return '$t AS $a';
  }

  @override
  RawExpression raw(value) => RawExpression(value);

  @override
  Future<bool> transaction(
    Future<bool> Function() action, [
    String? conditionName,
  ]) => ConnectionManager().transaction(action, conditionName);

  @override
  Stream<DatabaseAlert> alerts() => ConnectionManager().alerts;

  @override
  Map<String, PerformanceStats> getPerformanceStats() =>
      ConnectionManager().getPerformanceStats();

  @protected
  @override
  String build({String? aggregateFunction, String? aggregateColumn}) {
    final buf = StringBuffer();

    if (selectColumns.length > 1) {
      selectColumns.remove('*');
    }

    final withClause = buildWithClause();
    if (withClause.isNotEmpty) {
      buf.write(withClause);
      buf.write(' ');
    }

    final table = getTable;
    if (table.isNotEmpty) {
      if (aggregateFunction != null && aggregateColumn != null) {
        buf
          ..write('SELECT ')
          ..write(aggregateFunction)
          ..write('(')
          ..write(aggregateColumn)
          ..write(') FROM ')
          ..write(table);
      } else {
        buf.write('SELECT ');
        if (selectColumns.isEmpty) {
          buf.write('*');
        } else {
          buf.writeAll(selectColumns, ', ');
        }
        buf
          ..write(' FROM ')
          ..write(table);
      }

      if (joins.isNotEmpty) {
        buf.write(' ');
        buf.writeAll(joins, ' ');
      }
      if (conditions.isNotEmpty) {
        buf.write(' WHERE ');
        buf.writeAll(conditions, ' ');
      }

      if (unions.isNotEmpty) {
        buf.write(' ');
        buf.writeAll(unions, ' ');
      }

      if (aggregateFunction == null && aggregateColumn == null) {
        if (_groupBy.isNotEmpty) {
          buf.write(' GROUP BY ');
          buf.writeAll(_groupBy, ', ');
        }
        if (_having.isNotEmpty) {
          buf.write(' HAVING ');
          buf.writeAll(_having, ' ');
        }
        if (_orderBy.isNotEmpty) {
          buf.write(' ORDER BY ');
          buf.writeAll(_orderBy, ', ');
        }
        if (_limit != null) {
          buf
            ..write(' LIMIT ')
            ..write(_limit);
        }
        if (_offset != null) {
          buf
            ..write(' OFFSET ')
            ..write(_offset);
        }
      }
    } else if (conditions.isNotEmpty) {
      buf.writeAll(conditions, ' ');
    }

    return buf.toString().trim();
  }

  @override
  QueryBuilder connection([String? connection]) {
    connectionName = connection ?? _connectionName;
    return this;
  }

  @override
  QueryBuilder groupBy(List<String> groups) {
    SqlIdentifierGuard.columns(groups, context: 'GROUP BY column');
    _groupBy.addAll(groups);
    return this;
  }

  @override
  QueryBuilder groupByRaw(String expression) {
    _groupBy.add(expression);
    return this;
  }

  @override
  QueryBuilder having(
    String column, [
    String? operator,
    dynamic value,
    String boolean = 'and',
  ]) {
    SqlIdentifierGuard.column(column, context: 'HAVING column');
    String clause;
    if (operator != null && value != null) {
      SqlIdentifierGuard.operator(operator);
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

    SqlIdentifierGuard.column(column, context: 'HAVING column');

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
      // The seed is interpolated into the statement, so it has to be a
      // number. `inRandomOrder(request.input('seed'))` was otherwise a
      // direct injection point.
      if (seed is! num && num.tryParse(seed.toString()) == null) {
        throw InvalidArgumentException(
          'inRandomOrder seed must be numeric, got: "$seed".',
        );
      }
      _orderBy.add("RAND($seed)");
    } else {
      _orderBy.add("RAND()");
    }
    return this;
  }

  @override
  QueryBuilder latest([String column = 'created_at']) {
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
  QueryBuilder orderBy(String column, [String direction = 'ASC']) {
    SqlIdentifierGuard.column(column, context: 'ORDER BY column');
    _orderBy.add("$column ${SqlIdentifierGuard.direction(direction)}");
    return this;
  }

  @override
  QueryBuilder orderByRaw(String expression) {
    _orderBy.add(expression);
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
  QueryBuilder reorder([String? column, String? direction]) {
    _orderBy.clear();
    if (column != null) {
      SqlIdentifierGuard.column(column, context: 'ORDER BY column');
      _orderBy.add(
        "$column ${SqlIdentifierGuard.direction(direction ?? 'ASC')}",
      );
    }
    return this;
  }

  @override
  QueryBuilder table(String table, [String? as]) {
    SqlIdentifierGuard.table(table);
    if (as != null) SqlIdentifierGuard.alias(as);
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
    final whereB = (this as WhereClausesBuilderImpl).bindings;
    final cteB = getCteBindings();
    if (cteB.isEmpty) return whereB;

    final allBindings = <String, dynamic>{}
      ..addAll(whereB)
      ..addAll(cteB);
    return allBindings;
  }

  String _nextParamName() {
    _paramCounter++;
    return 'p$_paramCounter';
  }

  @override
  void resetQuery() {
    super.resetQuery();
    _orderBy.clear();
    _groupBy.clear();
    _having.clear();
    _limit = null;
    _offset = null;
    _paramCounter = 0;
    paramCounter = 0;
    resetCteState();
    resetWindowState();
  }
}
