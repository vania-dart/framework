import 'package:meta/meta.dart';
import 'package:vania/foundation.dart' show InvalidArgumentException;

import '../connection/connection_manager.dart';
import '../contract/database_connection.dart';
import '../monitoring/database_monitor.dart';

part '_paginated_result.dart';
part '_raw_expression.dart';
part '_bulk_operations_builder.dart';
part '_cte_builder.dart';
part '_delete_query_builder.dart';
part '_insert_query_builder.dart';
part '_join_clause_builder.dart';
part '_query_executor_builder.dart';
part '_select_query_builder.dart';
part '_union_clause_builder.dart';
part '_update_query_builder.dart';
part '_where_clauses_builder.dart';
part '_window_functions_builder.dart';

typedef QueryCallback = QueryBuilder Function(QueryBuilder qb);

abstract class QueryBuilder
    implements
        InsertQueryBuilder,
        UpdateQueryBuilder,
        WhereClausesBuilder,
        SelectQueryBuilder,
        DeleteQueryBuilder,
        UnionClauseBuilder,
        JoinClauseBuilder,
        QueryExecutorBuilder,
        WindowFunctionsBuilder,
        CteBuilder,
        BulkOperationsBuilder {
  @protected
  final List<String> conditions = [];
  @protected
  final Map<String, dynamic> bindings = {};
  @protected
  List<String> selectColumns = [];
  @protected
  List<String> joins = [];
  @protected
  List<String> unions = [];

  /// Drops every clause accumulated so far, leaving the table, alias and
  /// connection in place so the builder can be reused for a fresh query.
  ///
  /// A builder never clears itself after executing — `paginate` depends on
  /// that, since it runs `count()` and `get()` off the same clauses. But a
  /// builder that outlives one query (a `Model` held on a relation, say)
  /// would otherwise carry its old `WHERE`s into the next one.
  void resetQuery() {
    conditions.clear();
    bindings.clear();
    selectColumns = [];
    joins = [];
    unions = [];
  }

  @protected
  String build({String? aggregateFunction, String? aggregateColumn});
  String toSql();
  String toRawSql();

  @protected
  DatabaseConnection? get dbConnection =>
      ConnectionManager().connection(connectionName);

  @protected
  String get getTable => '';

  String? get connectionName;

  Future<DatabaseConnection> getConnection() async {
    if (!ConnectionManager().isConnected) {
      throw InvalidArgumentException('No database connection found.');
    }

    return dbConnection!;
  }

  QueryBuilder connection([String? connection]);

  QueryBuilder table(String table, [String? as]);

  /// Alias for [table]. Some drivers (document stores) prefer the
  /// "collection" spelling; both names route to the same underlying
  /// state on every driver.
  QueryBuilder collection(String name) => table(name);

  RawExpression raw(String value);

  Future<bool> transaction(
    Future<bool> Function() action, [
    String? conditionName,
  ]);

  Stream<DatabaseAlert> alerts();
  Map<String, PerformanceStats> getPerformanceStats();

  Map<String, dynamic> getBindings() {
    return bindings;
  }

  @protected
  String buildJoins() {
    return joins.isNotEmpty ? " ${joins.join(" ")}" : "";
  }

  @protected
  String buildWhereClause() {
    return conditions.isNotEmpty ? "WHERE ${conditions.join(" ")}" : "";
  }

  @protected
  String formatValue(dynamic value) {
    if (value is num) return value.toString();
    return "'$value'";
  }

  QueryBuilder groupBy(List<String> groups);

  /// Emits [expression] into GROUP BY verbatim.
  ///
  /// [groupBy] only accepts plain identifiers; use this when you
  /// deliberately need a SQL expression. Never pass user input here.
  QueryBuilder groupByRaw(String expression);
  QueryBuilder having(
    String column, [
    String? operator,
    dynamic value,
    String boolean = 'and',
  ]);

  QueryBuilder havingBetween(
    String column,
    List<dynamic> values, {
    String boolean = 'and',
    bool not = false,
  });
  QueryBuilder inRandomOrder([dynamic seed]);
  QueryBuilder latest([String column = 'created_at']);

  QueryBuilder limit(int value);
  QueryBuilder offset(int value);

  QueryBuilder orderBy(String column, [String direction = 'ASC']);

  /// Emits [expression] into ORDER BY verbatim.
  ///
  /// [orderBy] only accepts plain identifiers and ASC/DESC; use this when
  /// you deliberately need a SQL expression such as
  /// `orderByRaw('FIELD(status, 1, 2, 3)')`. Never pass user input here.
  QueryBuilder orderByRaw(String expression);

  QueryBuilder orderByAsc(String column);

  QueryBuilder orderByDesc(String column);
  QueryBuilder reorder([String? column, String? direction]);

  QueryBuilder skip(int value);

  QueryBuilder take(int value);
}
