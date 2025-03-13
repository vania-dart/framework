part of 'query_builder.dart';

abstract interface class UpdateQueryBuilder {
  Future<bool> decrement(
    String column, [
    int amount = 1,
    Map<String, dynamic> extra = const {},
  ]);
  Future<bool> increment(
    String column, [
    int amount = 1,
    Map<String, dynamic> extra = const {},
  ]);
  Future<bool> incrementEach(
    Map<String, int> increments, [
    Map<String, dynamic> extra = const {},
  ]);
  Future<bool> update(
    Map<String, dynamic> values,
  );

  Future<bool> updateMany(
    List<Map<String, dynamic>> updates,
    String column,
  );

  Future<bool> updateOrInsert(
    Map<String, dynamic> search,
    Map<String, dynamic> update,
  );
}
