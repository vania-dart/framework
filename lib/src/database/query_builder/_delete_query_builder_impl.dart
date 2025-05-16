import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder;

abstract mixin class DeleteQueryBuilderImpl implements QueryBuilder {
  @override
  Future<bool> delete() async {
    try {
      final sql = "DELETE FROM $table${buildWhereClause()}";
      return await getConnection().execute(sql, bindings);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> truncate() async {
    try {
      String sql = "TRUNCATE TABLE $table";
      await dbConnection?.execute(sql);
      return true;
    } catch (e) {
      rethrow;
    }
  }
}
