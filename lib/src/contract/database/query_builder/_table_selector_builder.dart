part of 'query_builder.dart';

abstract interface class TableSelector {
  QueryBuilder table(String table, [String? as]);
}
