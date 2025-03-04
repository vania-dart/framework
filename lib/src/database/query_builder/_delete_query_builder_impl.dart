import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder;

abstract mixin class DeleteQueryBuilderImpl implements QueryBuilder {
  @override
  Future<bool> delete() async {
    String sql = "DELETE FROM $table${buildJoins()} ${buildWhereClause()}";
    await dbConnection?.execute(sql);
    return true;
  }

  @override
  Future<bool> truncate() async {
    String sql = "TRUNCATE TABLE $table";
    await dbConnection?.execute(sql);
    return true;
  }
}
