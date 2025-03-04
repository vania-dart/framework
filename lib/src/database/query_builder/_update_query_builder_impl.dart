import '../../contract/database/query_builder/query_builder.dart'
    show QueryBuilder;

abstract mixin class UpdateQueryBuilderImpl implements QueryBuilder {
  @override
  Future<bool> update(Map<String, dynamic> values) async {
    String setClause = values.entries
        .map((e) => "${e.key} = ${formatValue(e.value)}")
        .join(", ");

    String sql =
        "UPDATE $table${buildJoins()} SET $setClause ${buildWhereClause()}";
        print(sql);
    await dbConnection?.execute(sql);
    return true;
  }

  @override
  Future<bool> updateMany(
    List<Map<String, dynamic>> updates,
    String column,
  ) async {
    if (updates.isEmpty) return false;
    Set<String> columns = {};
    for (var row in updates) {
      row.forEach((key, value) {
        if (key != column) columns.add(key);
      });
    }
    List<String> setClauses = [];
    for (var col in columns) {
      String cases = updates.map((row) {
        var keyValue = row[column];
        var value = row[col];
        return "WHEN $column = ${formatValue(keyValue)} THEN ${formatValue(value)}";
      }).join(" ");
      String clause = "$col = CASE $cases ELSE $col END";
      setClauses.add(clause);
    }
    String keys = updates.map((row) => formatValue(row[column])).join(", ");
    String sql =
        "UPDATE $table${buildJoins()} SET ${setClauses.join(", ")} WHERE $column IN ($keys)";
    await dbConnection?.execute(sql);
    return true;
  }

  @override
  Future<bool> updateOrInsert(
      Map<String, dynamic> search, Map<String, dynamic> update) async {
    Map<String, dynamic> data = {}
      ..addAll(search)
      ..addAll(update);

    upsert(data, search.keys.toList(), update);

    return true;
  }

  @override
  Future<bool> decrement(
    String column, [
    int amount = 1,
    Map<String, dynamic> extra = const {},
  ]) async {
    String setClause = "$column = $column - $amount";
    if (extra.isNotEmpty) {
      String extraClause = extra.entries
          .map((e) => "${e.key} = ${formatValue(e.value)}")
          .join(", ");
      setClause += ", $extraClause";
    }
    String sql =
        "UPDATE $table${buildJoins()} SET $setClause ${buildWhereClause()}";
    await dbConnection?.execute(sql);
    return true;
  }

  @override
  Future<bool> increment(
    String column, [
    int amount = 1,
    Map<String, dynamic> extra = const {},
  ]) async {
    String setClause = "$column = $column + $amount";
    if (extra.isNotEmpty) {
      String extraClause = extra.entries
          .map((e) => "${e.key} = ${formatValue(e.value)}")
          .join(", ");
      setClause += ", $extraClause";
    }
    String sql =
        "UPDATE $table${buildJoins()} SET $setClause ${buildWhereClause()}";
    await dbConnection?.execute(sql);
    return true;
  }

  @override
  Future<bool> incrementEach(
    Map<String, int> increments, [
    Map<String, dynamic> extra = const {},
  ]) async {
    String setClause = increments.entries
        .map((e) => "${e.key} = ${e.key} + ${e.value}")
        .join(", ");
    if (extra.isNotEmpty) {
      String extraClause = extra.entries
          .map((e) => "${e.key} = ${formatValue(e.value)}")
          .join(", ");
      setClause += ", $extraClause";
    }

    String sql =
        "UPDATE $table${buildJoins()} SET $setClause${buildWhereClause()}";
    await dbConnection?.execute(sql);
    return true;
  }
}
