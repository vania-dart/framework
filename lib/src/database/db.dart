// ignore_for_file: non_constant_identifier_names

import '../contract/database/query_builder/query_builder.dart';
import '_connection_manager.dart';
import 'query_builder/_query_builder_impl.dart' show QueryBuilderImpl;
import 'monitoring/database_monitor.dart';

QueryBuilder DB(String table, {String? as, String? connection}) =>
    QueryBuilderImpl().connection(connection).setTable(
          table,
          as,
        );
String DBraw(value) => RawExpression(value).toString();

Future<bool> DB_Transaction(
  Future<dynamic> Function() queries, [
  String? conditionName,
]) =>
    ConnectionManager().transaction(queries, conditionName);

Stream<DatabaseAlert> DBAlerts() => ConnectionManager().alerts;
Map<String, PerformanceStats> DBGetPerformanceStats() =>
    ConnectionManager().getPerformanceStats();
