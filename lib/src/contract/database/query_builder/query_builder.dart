import 'package:meta/meta.dart';
import '../../../database/monitoring/database_monitor.dart';
import '../../../exception/invalid_argument_exception.dart';

import '../../../database/_connection_manager.dart';
import '../_connectors/_database_connection.dart';

part '../../../database/_database_utils/_paginated_result.dart';
part '../../../database/_database_utils/_raw_expression.dart';
part '_delete_query_builder.dart';
part '_insert_query_builder.dart';
part '_join_clause_builder.dart';
part '_where_clauses_builder.dart';
part '_query_executor_builder.dart';
part '_select_query_builder.dart';
part '_union_clause_builder.dart';
part '_update_query_builder.dart';
part '_window_functions_builder.dart';
part '_cte_builder.dart';
part '_bulk_operations_builder.dart';

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

  String raw(value);

  Future<bool> transaction(
    Future<dynamic> Function() queries, [
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
  String formatValue(
    dynamic value,
  ) {
    if (value is num) return value.toString();
    return "'$value'";
  }

  QueryBuilder groupBy(
    List<String> groups,
  );
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
  QueryBuilder inRandomOrder([
    dynamic seed,
  ]);
  QueryBuilder latest([
    String column = 'created_at',
  ]);

  QueryBuilder limit(int value);
  QueryBuilder offset(int value);

  QueryBuilder orderBy(
    String column, [
    String direction = 'ASC',
  ]);

  QueryBuilder orderByAsc(
    String column,
  );

  QueryBuilder orderByDesc(
    String column,
  );
  QueryBuilder reorder([
    String? column,
    String? direction,
  ]);

  QueryBuilder skip(int value);

  QueryBuilder take(int value);
}
