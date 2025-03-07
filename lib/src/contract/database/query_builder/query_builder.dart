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
part '_table_selector_builder.dart';
part '_union_clause_builder.dart';
part '_update_query_builder.dart';

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
        QueryExecutorBuilder {
  final List<String> conditions = [];
  final Map<String, dynamic> bindings = {};

  DatabaseConnection? get dbConnection =>
      ConnectionManager().connection(connectionName);
  String get table => '';
  String? get connectionName;

  DatabaseConnection getConnection() {
    if (dbConnection == null) {
      throw InvalidArgumentException('Database connection not set');
    }
    return dbConnection!;
  }

  Map<String, dynamic> getBindings() {
    return bindings;
  }

  String build({String? aggregateFunction, String? aggregateColumn});
  String toSql();

  List<String> selectColumns = [];
  List<String> joins = [];
  List<String> unions = [];

  String buildJoins() {
    return joins.isNotEmpty ? " ${joins.join(" ")}" : "";
  }

  String buildWhereClause() {
    return conditions.isNotEmpty ? "WHERE ${conditions.join(" ")}" : "";
  }

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
