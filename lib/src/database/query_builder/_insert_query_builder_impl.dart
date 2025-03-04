import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder;

abstract mixin class InsertQueryBuilderImpl implements QueryBuilder {
  @override
  Future<bool> insert(
    Map<String, dynamic> values,
  ) async {
    var columns = values.keys.toList();
    String cols = columns.join(", ");
    String vals = columns.map((col) => formatValue(values[col])).join(", ");
    String sql = "INSERT INTO $table ($cols) VALUES ($vals)";
    await dbConnection?.execute(sql);
    return true;
  }

  @override
  Future insertGetId(
    Map<String, dynamic> values, [
    String? sequence,
  ]) async {
    var columns = values.keys.toList();
    String cols = columns.join(", ");
    String vals = columns.map((col) => formatValue(values[col])).join(", ");
    String sql = "INSERT INTO $table ($cols) VALUES ($vals)";
    final id = await dbConnection?.insert(sql);
    return id;
  }

  @override
  Future<bool> insertMany(
    List<Map<String, dynamic>> valuesList,
  ) async {
    if (valuesList.isEmpty) return false;
    var columns = valuesList.first.keys.toList();
    String cols = columns.join(", ");
    String vals = valuesList.map((values) {
      String row = columns.map((col) => formatValue(values[col])).join(", ");
      return "($row)";
    }).join(", ");
    String sql = "INSERT INTO $table ($cols) VALUES $vals";
    await dbConnection?.execute(sql);
    return true;
  }

  @override
  Future<bool> insertOrIgnore(
    Map<String, dynamic> values,
  ) async {
    var columns = values.keys.toList();
    String cols = columns.join(", ");
    String vals = columns.map((col) => formatValue(values[col])).join(", ");
    String sql = "INSERT IGNORE INTO $table ($cols) VALUES ($vals)";
    await dbConnection?.execute(sql);
    return true;
  }

  @override
  Future<bool> insertUsing(
    List<String> columns,
    QueryBuilder subQuery,
  ) async {
    String cols = columns.join(", ");
    String subSql = subQuery.toSql();
    String sql = "INSERT INTO $table ($cols) $subSql";
    await dbConnection?.execute(sql);
    return true;
  }

  @override
  Future<bool> upsert(
    Map<String, dynamic> values,
    List<String> uniqueBy, [
    Map<String, dynamic>? update,
  ]) async {
    var columns = values.keys.toList();
    String cols = columns.join(", ");
    String vals = columns.map((col) => formatValue(values[col])).join(", ");

    String sql = "INSERT INTO $table ($cols) VALUES ($vals)";

    if (update == null) {
      update = Map.from(values);
      for (var col in uniqueBy) {
        update.remove(col);
      }
    }

    if (update.isNotEmpty) {
      String updates = update.entries
          .map((e) => "${e.key} = ${formatValue(e.value)}")
          .join(", ");
      sql += " ON DUPLICATE KEY UPDATE $updates";
    }

    await dbConnection?.execute(sql);
    return true;
  }
}
