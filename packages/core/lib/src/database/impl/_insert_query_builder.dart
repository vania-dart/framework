part of 'legacy_query_builder.dart';

abstract interface class InsertQueryBuilder {
  Future<bool> insert(Map<String, dynamic> values);
  Future insertGetId(Map<String, dynamic> values, [String? sequence]);
  Future<bool> insertMany(List<Map<String, dynamic>> values);
  Future<bool> insertOrIgnore(Map<String, dynamic> values);
  Future<bool> insertUsing(List<String> columns, QueryBuilder subQuery);
  Future<bool> upsert(
    Map<String, dynamic> values,
    List<String> uniqueBy, [
    Map<String, dynamic>? update,
  ]);
}
