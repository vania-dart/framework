import '../contract/database_connection.dart';
import '../impl/legacy_query_builder.dart' show QueryBuilder;

abstract mixin class DeleteQueryBuilderImpl implements QueryBuilder {
  late DatabaseConnection conn;
  @override
  Future<bool> delete() async {
    try {
      final sql = "DELETE FROM $getTable${buildWhereClause()}";
      conn = await getConnection();
      return await conn.execute(sql, bindings);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> truncate({bool force = false}) async {
    try {
      String sql = "TRUNCATE TABLE $getTable";
      if (force) {
        sql = "SET FOREIGN_KEY_CHECKS=0; $sql; SET FOREIGN_KEY_CHECKS=1;";
      }
      conn = await getConnection();
      await conn.execute(sql);
      return true;
    } catch (e) {
      rethrow;
    }
  }
}
